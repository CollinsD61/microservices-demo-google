# =============================================================================
# VPC MODULE VARIABLES
# =============================================================================

variable "project_name" {
  description = "Tên project"
  type        = string
}

variable "environment" {
  description = "Môi trường: dev hoặc prod"
  type        = string
}

variable "cluster_name" {
  description = "Tên EKS cluster (dùng cho tags)"
  type        = string
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Danh sách Availability Zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks cho public subnets (phải khớp với số AZs)"
  type        = list(string)
  default     = ["10.0.0.0/22", "10.0.4.0/22"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks cho private subnets (phải khớp với số AZs)"
  type        = list(string)
  default     = ["10.0.8.0/22", "10.0.12.0/22"]
}

# -----------------------------------------------------------------------------
# Tối ưu chi phí
# -----------------------------------------------------------------------------

variable "single_nat_gateway" {
  description = <<-EOT
    true = Dùng 1 NAT Gateway (tiết kiệm ~$32/tháng mỗi NAT, phù hợp Dev)
    false = Mỗi AZ có 1 NAT Gateway (High Availability, phù hợp Prod)
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags chung cho tất cả resources"
  type        = map(string)
  default     = {}
}
