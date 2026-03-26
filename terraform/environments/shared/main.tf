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


# 1. Tạo OIDC Provider để AWS chấp nhận Token từ GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # Thumbprint của GitHub (Giá trị này ít khi thay đổi)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# 2. Tạo IAM Role cho GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  # Trust Policy: Chỉ cho phép Repo của bạn được phép mượn quyền của Role này
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            # QUAN TRỌNG: Thay bằng tên GitHub của bạn và tên Repo
            "token.actions.githubusercontent.com:sub": "repo:CollinsD61/microservices-demo-google:*"
          }
        }
      }
    ]
  })
}

# 3. Cấp quyền cho Role (Tạm thời dùng PowerUser để build và push ECR/EKS)
resource "aws_iam_role_policy_attachment" "gha_power_user" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}