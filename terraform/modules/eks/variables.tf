# =============================================================================
# EKS MODULE VARIABLES
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
  description = "Tên EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Phiên bản Kubernetes"
  type        = string
  default     = "1.34"
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID của VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List subnet IDs cho EKS (private subnets)"
  type        = list(string)
}

variable "enable_public_access" {
  description = "Cho phép truy cập API server từ internet"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Node Group Configuration
# -----------------------------------------------------------------------------

variable "instance_types" {
  description = <<-EOT
    List instance types cho node group
    Dev: ["t3.medium"] - tiết kiệm chi phí
    Prod: ["t3.large", "t3.xlarge"] - performance tốt hơn
  EOT
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = <<-EOT
    Loại capacity:
    SPOT - Tiết kiệm 60-90% (phù hợp Dev, non-critical workloads)
    ON_DEMAND - Ổn định, đắt hơn (phù hợp Production)
  EOT
  type        = string
  default     = "ON_DEMAND"
}

variable "disk_size" {
  description = "Dung lượng disk (GB) cho mỗi node"
  type        = number
  default     = 50
}

variable "node_min_size" {
  description = "Số nodes tối thiểu"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Số nodes tối đa"
  type        = number
  default     = 5
}

variable "node_desired_size" {
  description = "Số nodes mong muốn"
  type        = number
  default     = 2
}

variable "node_labels" {
  description = "Labels cho nodes"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Features
# -----------------------------------------------------------------------------

variable "enable_ssm" {
  description = "Bật SSM để debug nodes"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags chung cho resources"
  type        = map(string)
  default     = {}
}
