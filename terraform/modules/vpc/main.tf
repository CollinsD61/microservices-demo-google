# =============================================================================
# VPC MODULE - Tối ưu cho EKS và tiết kiệm chi phí
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs_count   = length(var.availability_zones)
}

data "aws_region" "current" {}


# =============================================================================
# VPC
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# =============================================================================
# INTERNET GATEWAY - Cho public subnets
# =============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# =============================================================================
# PUBLIC SUBNETS - Cho Load Balancer, NAT Gateway
# =============================================================================

resource "aws_subnet" "public" {
  count = local.azs_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  # Tags bắt buộc cho EKS để tự động tạo Load Balancer
  tags = merge(var.tags, {
    Name                                        = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# =============================================================================
# PRIVATE SUBNETS - Cho EKS Worker Nodes
# =============================================================================

resource "aws_subnet" "private" {
  count = local.azs_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Tags bắt buộc cho EKS internal load balancers
  tags = merge(var.tags, {
    Name                                        = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# =============================================================================
# ELASTIC IP - Cho NAT Gateway
# =============================================================================

resource "aws_eip" "nat" {
  # Dev: 1 NAT Gateway để tiết kiệm (~$32/tháng mỗi NAT)
  # Prod: 1 NAT Gateway mỗi AZ cho High Availability
  count  = var.single_nat_gateway ? 1 : local.azs_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT GATEWAY - Cho private subnets ra internet
# =============================================================================

resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : local.azs_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# ROUTE TABLES
# =============================================================================

# Public Route Table - Chung cho tất cả public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = local.azs_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables
resource "aws_route_table" "private" {
  # Nếu single_nat_gateway: 1 route table dùng chung
  # Nếu không: mỗi AZ có route table riêng
  count  = var.single_nat_gateway ? 1 : local.azs_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = local.azs_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# =============================================================================
# PRE-DELETE CLEANUP
# null_resource này phụ thuộc vào subnet/IGW/NAT
# => Terraform destroy nó TRƯÉC khi xóa subnet/IGW
# => cleanup chạy đúng lúc: sau khi EKS góc đã xóa, trước khi VPC resource bị xóa
# =============================================================================

resource "null_resource" "pre_vpc_delete_cleanup" {
  triggers = {
    vpc_id = aws_vpc.main.id
    region = data.aws_region.current.name
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-Command"]
    command     = <<EOT
      $vpcId  = "${self.triggers.vpc_id}"
      $region = "${self.triggers.region}"

      Write-Host "[VPC Cleanup] Starting pre-delete cleanup for VPC $vpcId..." -ForegroundColor Yellow

      # --- [1/3] Tim va xoa ALB/NLB con lai trong VPC ---
      Write-Host "[VPC Cleanup][1/3] Checking for orphaned Load Balancers..."
      $albsRaw = aws elbv2 describe-load-balancers --region $region --output json 2>&1
      if ($LASTEXITCODE -eq 0) {
        $albs = ($albsRaw | ConvertFrom-Json).LoadBalancers | Where-Object { $_.VpcId -eq $vpcId }
        if ($albs.Count -gt 0) {
          foreach ($alb in $albs) {
            Write-Host "[VPC Cleanup]  -> Deleting ALB: $($alb.LoadBalancerName)"
            aws elbv2 delete-load-balancer --load-balancer-arn $alb.LoadBalancerArn --region $region 2>&1 | Out-Null
          }
          Write-Host "[VPC Cleanup]  Waiting 90s for AWS to release ALB ENIs..."
          Start-Sleep -Seconds 90
        } else {
          Write-Host "[VPC Cleanup]  No orphaned ALBs found."
        }
      }

      # --- [2/3] Xoa orphan SGs (k8s-*) ---
      Write-Host "[VPC Cleanup][2/3] Checking for orphaned Security Groups (k8s-*)..."
      $sgsRaw = aws ec2 describe-security-groups `
        --filters "Name=vpc-id,Values=$vpcId" "Name=group-name,Values=k8s-*" `
        --query "SecurityGroups[].{ID:GroupId,Name:GroupName}" `
        --output json --region $region 2>&1
      if ($LASTEXITCODE -eq 0) {
        $sgs = $sgsRaw | ConvertFrom-Json
        foreach ($sg in $sgs) {
          Write-Host "[VPC Cleanup]  -> Deleting SG: $($sg.ID) ($($sg.Name))"
          aws ec2 delete-security-group --group-id $sg.ID --region $region 2>&1 | Out-Null
        }
        if ($sgs.Count -eq 0) { Write-Host "[VPC Cleanup]  No orphaned SGs found." }
      }

      # --- [3/3] Kiem tra ENI con lai ---
      Write-Host "[VPC Cleanup][3/3] Checking for remaining ENIs..."
      $enis = aws ec2 describe-network-interfaces `
        --filters "Name=vpc-id,Values=$vpcId" `
        --query "NetworkInterfaces[?Status!='available'].NetworkInterfaceId" `
        --output json --region $region 2>&1 | ConvertFrom-Json
      if ($enis.Count -gt 0) {
        Write-Host "[VPC Cleanup]  Found $($enis.Count) non-available ENI(s). Waiting 30s..."
        Start-Sleep -Seconds 30
      } else {
        Write-Host "[VPC Cleanup]  All ENIs available/cleared."
      }

      Write-Host "[VPC Cleanup] Done! VPC resources can now be safely deleted." -ForegroundColor Green
    EOT
  }

  # Depends on ALL VPC sub-resources => destroyed BEFORE them (guaranteed ordering)
  depends_on = [
    aws_subnet.public,
    aws_subnet.private,
    aws_internet_gateway.main,
    aws_nat_gateway.main,
    aws_eip.nat,
    aws_route_table.public,
    aws_route_table.private,
    aws_route_table_association.public,
    aws_route_table_association.private,
  ]
}
