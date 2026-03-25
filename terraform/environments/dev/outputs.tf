# =============================================================================
# DEV ENVIRONMENT OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "Dev VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "Dev EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Dev EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Command để kết nối kubectl với Dev cluster"
  value       = module.eks.configure_kubectl
}

# Chi phí ước tính
output "cost_estimate" {
  description = "Chi phí ước tính hàng tháng cho Dev"
  value       = <<-EOT
    ========================================
    DEV ENVIRONMENT - Chi phí ước tính
    ========================================
    EKS Control Plane: ~$73/tháng
    NAT Gateway (1x):  ~$32/tháng + data transfer
    EC2 Spot (2x t3.medium): ~$15-30/tháng
    ----------------------------------------
    TỔNG ƯỚC TÍNH: ~$120-140/tháng
    ========================================
    * Giá có thể thay đổi theo region và usage
  EOT
}
