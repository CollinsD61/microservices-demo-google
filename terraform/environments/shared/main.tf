# =============================================================================
# SHARED RESOURCES - ECR (Dùng chung cho Dev và Prod)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "shared/ecr/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Shared    = "true"
    }
  }
}

# =============================================================================
# ECR REPOSITORIES
# =============================================================================

module "ecr" {
  source = "../../modules/ecr"

  project_name         = var.project_name
  repository_list      = var.repository_list
  image_tag_mutability = "MUTABLE"
  encryption_type      = "AES256"

  # Lifecycle policy settings
  prod_image_count   = 15
  dev_image_count    = 5
  max_image_age_days = 90

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Shared    = "true"
  }
}
