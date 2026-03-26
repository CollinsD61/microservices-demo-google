# =============================================================================
# PRODUCTION ENVIRONMENT OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "Prod VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "Prod EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Prod EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command để kết nối kubectl với Prod cluster"
  value       = module.eks.configure_kubectl
}

# Chi phí ước tính
output "cost_estimate" {
  description = "Chi phí ước tính hàng tháng cho Production"
  value       = <<-EOT
    ========================================
    PROD ENVIRONMENT - Chi phí ước tính
    ========================================
    EKS Control Plane: ~$73/tháng
    NAT Gateway (2x):  ~$64/tháng + data transfer
    EC2 On-Demand (3x t3.large): ~$180-220/tháng
    EKS Logging (CloudWatch): ~$10-30/tháng
    ----------------------------------------
    TỔNG ƯỚC TÍNH: ~$330-400/tháng
    ========================================
    * Giá có thể thay đổi theo region và usage
    * Chi phí có thể tăng khi scale nodes
  EOT
}
