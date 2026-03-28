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

  project_name       = var.project_name
  environment        = local.environment
  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
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
  node_desired_size = 2

  enable_public_access = true
  enable_ssm           = true # Bật SSM để debug

  tags = var.tags
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
  service_type  = "LoadBalancer" # Dùng LoadBalancer ở Dev để dễ dàng truy cập IP ngoài
  
  cluster_name  = local.cluster_name
  aws_region    = var.aws_region

  depends_on = [
    module.eks,
    module.eks.node_group_arn # Wait cho node group sẵn sàng
  ]
}
