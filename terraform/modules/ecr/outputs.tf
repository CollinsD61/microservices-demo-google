# =============================================================================
# ECR MODULE OUTPUTS
# =============================================================================

output "repository_urls" {
  description = "Map của service name -> ECR repository URL"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.repository_url }
}

output "repository_arns" {
  description = "Map của service name -> ECR repository ARN (cho IAM policies)"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.arn }
}

output "registry_id" {
  description = "AWS Account ID của ECR registry"
  value       = try(values(aws_ecr_repository.microservices)[0].registry_id, "")
}
