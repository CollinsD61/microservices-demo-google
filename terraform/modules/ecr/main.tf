# =============================================================================
# ECR REPOSITORIES - Dùng chung cho cả Dev và Production
# =============================================================================

resource "aws_ecr_repository" "microservices" {
  for_each             = toset(var.repository_list)
  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  # Mã hóa images với KMS (bảo mật hơn)
  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  tags = merge(var.tags, {
    Service = each.key
    Name    = "${var.project_name}-${each.key}"
  })
}

# =============================================================================
# LIFECYCLE POLICY - Tối ưu chi phí lưu trữ
# =============================================================================

resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    rules = [
      # Rule 1: Xóa untagged images sau 1 ngày (tiết kiệm chi phí)
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      # Rule 2: Giữ N images gần nhất cho production tags
      {
        rulePriority = 2
        description  = "Keep last ${var.prod_image_count} production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-", "release-", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.prod_image_count
        }
        action = {
          type = "expire"
        }
      },
      # Rule 3: Giữ ít images hơn cho dev tags (tiết kiệm chi phí)
      {
        rulePriority = 3
        description  = "Keep last ${var.dev_image_count} dev images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-", "feature-", "test-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.dev_image_count
        }
        action = {
          type = "expire"
        }
      },
      # Rule 4: Xóa tất cả images cũ hơn N ngày
      {
        rulePriority = 4
        description  = "Remove images older than ${var.max_image_age_days} days"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.max_image_age_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
