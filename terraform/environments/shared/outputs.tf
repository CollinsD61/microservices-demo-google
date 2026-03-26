# =============================================================================
# SHARED RESOURCES OUTPUTS
# =============================================================================

output "ecr_repository_urls" {
  description = "Map của service -> ECR URL"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map của service -> ECR ARN"
  value       = module.ecr.repository_arns
}
