# =============================================================================
# DEV ENVIRONMENT - Tối ưu chi phí
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # Backend configuration - uncomment và cấu hình cho môi trường thực
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "dev/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  environment  = "dev"
  cluster_name = "${var.project_name}-${local.environment}"
}

# =============================================================================
# VPC
# =============================================================================

module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = local.environment
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # DEV: Dùng 1 NAT Gateway để tiết kiệm ~$32/tháng
  single_nat_gateway = true

  tags = var.tags
}

# =============================================================================
# EKS
# =============================================================================

module "eks" {
  source = "../../modules/eks"

  project_name    = var.project_name
  environment     = local.environment
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # DEV: Dùng SPOT instances để tiết kiệm 60-90%
  instance_types = ["t3.medium", "t2.medium"]
  capacity_type  = "SPOT"
  disk_size      = 30

  # DEV: Scale nhỏ hơn
  node_min_size     = 1
  node_max_size     = 3
  node_desired_size = 3

  enable_public_access = true
  enable_ssm           = true # Bật SSM để debug

  tags = var.tags
}

# =============================================================================
# ALB CONTROLLER & EXTERNAL DNS
# =============================================================================

module "alb_controller" {
  source = "../../modules/alb_controller"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vpc_id            = module.vpc.vpc_id

  depends_on = [
    module.eks,
    module.eks.node_group_arn
  ]
}

module "external_dns" {
  source = "../../modules/external_dns"

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_domain    = "dohoangdevops.io.vn"

  depends_on = [
    module.eks,
    module.eks.node_group_arn
  ]
}

# =============================================================================
# HELM PROVIDER & ARGOCD
# =============================================================================

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
      command     = "aws"
    }
  }
}

module "argocd" {
  source = "../../modules/argocd"

  # Dev env specific configurations
  chart_version = "5.51.6"
  namespace     = "argocd"
  service_type  = "ClusterIP" # Dùng ClusterIP 

  cluster_name = local.cluster_name
  aws_region   = var.aws_region

  values = <<EOF
server:
  ingress:
    enabled: true
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/group.name: "dev-shared-alb"
      alb.ingress.kubernetes.io/backend-protocol: HTTPS
      external-dns.alpha.kubernetes.io/hostname: "argocd.dohoangdevops.io.vn"
      external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    hosts:
      - argocd.dohoangdevops.io.vn
EOF

  depends_on = [
    module.eks,
    module.eks.node_group_arn, # Wait cho node group sẵn sàng
    module.alb_controller      # Đảm bảo AWS ALB Controller (webhook) chạy xong trước khi ArgoCD tạo Services/Ingress
  ]
}

# =============================================================================
# PRE-DESTROY CLEANUP
# Chạy TRƯỚC KHI Terraform xóa VPC/Subnets.
# Dọn tất cả AWS resources do Kubernetes tạo ra (ngoài tầm Terraform):
#   - AWS ALB/NLB (từ Service type=LoadBalancer và Ingress)
#   - Security Groups (k8s-* tạo bởi ALB Controller)
#   - Elastic Network Interfaces (tự release sau khi ALB bị xóa)
#
# Cơ chế: null_resource này depends_on [argocd, alb_controller, eks]
# => Terraform destroy nó ĐẦU TIÊN, sau đó mới destroy theo thứ tự ngược.
# Order: pre_destroy_cleanup → ArgoCD → ALB Controller → EKS → VPC ✅
# =============================================================================

resource "null_resource" "pre_destroy_cleanup" {
  # Lưu các giá trị cần dùng khi destroy vào triggers (được lưu trong state)
  triggers = {
    cluster_name = local.cluster_name
    region       = var.aws_region
    vpc_id       = module.vpc.vpc_id
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-Command"]
    command     = <<EOT
      $clusterName = "${self.triggers.cluster_name}"
      $region      = "${self.triggers.region}"
      $vpcId       = "${self.triggers.vpc_id}"

      Write-Host ""
      Write-Host "================================================" -ForegroundColor Yellow
      Write-Host " PRE-DESTROY CLEANUP (tu dong)" -ForegroundColor Yellow
      Write-Host " Cluster : $clusterName" -ForegroundColor Yellow
      Write-Host " VPC     : $vpcId" -ForegroundColor Yellow
      Write-Host "================================================" -ForegroundColor Yellow

      # --- [1/4] Ket noi EKS ---
      Write-Host ""
      Write-Host "[1/4] Connecting to EKS cluster..." -ForegroundColor Cyan
      aws eks update-kubeconfig --region $region --name $clusterName 2>&1 | Out-Null

      if ($LASTEXITCODE -eq 0) {
        # --- [2/4] Xoa LoadBalancer Services (giai phong ALB/NLB) ---
        Write-Host ""
        Write-Host "[2/4] Deleting all LoadBalancer-type Services..." -ForegroundColor Cyan
        $svcsJson = kubectl get svc --all-namespaces -o json --request-timeout=15s 2>&1
        if ($LASTEXITCODE -eq 0) {
          $svcs = $svcsJson | ConvertFrom-Json
          $lbSvcs = $svcs.items | Where-Object { $_.spec.type -eq "LoadBalancer" }
          if ($lbSvcs.Count -gt 0) {
            foreach ($svc in $lbSvcs) {
              Write-Host "  -> Deleting svc/$($svc.metadata.name) in ns/$($svc.metadata.namespace)" -ForegroundColor White
              kubectl delete svc $svc.metadata.name -n $svc.metadata.namespace --ignore-not-found --wait=false --request-timeout=15s 2>&1 | Out-Null
            }
          } else {
            Write-Host "  No LoadBalancer services found." -ForegroundColor Gray
          }
        }

        # Xoa Ingress (giai phong ALB gan ingress group)
        Write-Host "  Deleting all Ingresses..." -ForegroundColor Gray
        kubectl delete ingress --all --all-namespaces --ignore-not-found --wait=false --request-timeout=15s 2>&1 | Out-Null

        # --- [3/4] Cho AWS decommission ALB va release ENI ---
        Write-Host ""
        Write-Host "[3/4] Waiting 120s for AWS to decommission ALBs and release ENIs..." -ForegroundColor Cyan
        $wait = 120
        while ($wait -gt 0) {
          Write-Host "  ... $wait s remaining" -ForegroundColor DarkGray
          Start-Sleep -Seconds 20
          $wait -= 20
        }
      } else {
        Write-Warning "[1/4] Cannot connect to EKS (may already be deleted). Skipping K8s cleanup."
      }

      # --- [4/4] Xoa orphan Security Groups (k8s-*) do ALB Controller tao ---
      Write-Host ""
      Write-Host "[4/4] Deleting orphan Security Groups (k8s-*) in VPC $vpcId..." -ForegroundColor Cyan
      $sgsJson = aws ec2 describe-security-groups `
        --filters "Name=vpc-id,Values=$vpcId" `
        --query "SecurityGroups[?starts_with(GroupName, ``k8s-``)].{ID:GroupId,Name:GroupName}" `
        --output json --region $region 2>&1
      if ($LASTEXITCODE -eq 0 -and $sgsJson -ne "[]") {
        $sgs = $sgsJson | ConvertFrom-Json
        foreach ($sg in $sgs) {
          Write-Host "  -> Deleting SG $($sg.ID) ($($sg.Name))" -ForegroundColor White
          aws ec2 delete-security-group --group-id $sg.ID --region $region 2>&1 | Out-Null
        }
      } else {
        Write-Host "  No orphan k8s-* security groups found." -ForegroundColor Gray
      }

      Write-Host ""
      Write-Host "================================================" -ForegroundColor Green
      Write-Host " Pre-destroy cleanup DONE!" -ForegroundColor Green
      Write-Host " Terraform co the xoa VPC/Subnets an toan." -ForegroundColor Green
      Write-Host "================================================" -ForegroundColor Green
    EOT
  }

  depends_on = [
    module.argocd,
    module.alb_controller,
    module.external_dns,
    module.eks,
    module.vpc,
  ]
}

