# =============================================================================
# PRODUCTION ENVIRONMENT VARIABLES
# =============================================================================

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Tên project"
  type        = string
  default     = "online-boutique"
}

variable "cluster_version" {
  description = "Phiên bản Kubernetes"
  type        = string
  default     = "1.29"
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR cho Prod VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "Các AZ sử dụng"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR cho public subnets"
  type        = list(string)
  default     = ["10.1.0.0/22", "10.1.4.0/22"]
}

variable "private_subnet_cidrs" {
  description = "CIDR cho private subnets"
  type        = list(string)
  default     = ["10.1.8.0/22", "10.1.12.0/22"]
}

variable "enable_public_access" {
  description = "Cho phép public access tới EKS API"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags chung"
  type        = map(string)
  default     = {}
}
