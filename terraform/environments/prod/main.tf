# =============================================================================
# PRODUCTION ENVIRONMENT - High Availability
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration - uncomment và cấu hình cho môi trường thực
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "prod/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  environment  = "prod"
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

  # PROD: Mỗi AZ có 1 NAT Gateway cho High Availability
  single_nat_gateway = false

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

  # PROD: Dùng On-Demand cho ổn định, instance lớn hơn
  instance_types = ["t3.large", "t3.xlarge"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 50

  # PROD: Scale lớn hơn cho production workloads
  node_min_size     = 2
  node_max_size     = 10
  node_desired_size = 3

  # PROD: Giới hạn public access, dùng VPN/bastion
  enable_public_access = var.enable_public_access
  enable_ssm           = false

  tags = var.tags
}
