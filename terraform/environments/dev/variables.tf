# =============================================================================
# DEV ENVIRONMENT VARIABLES
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
  description = "CIDR cho Dev VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Các AZ sử dụng"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR cho public subnets"
  type        = list(string)
  default     = ["10.0.0.0/22", "10.0.4.0/22"]
}

variable "private_subnet_cidrs" {
  description = "CIDR cho private subnets"
  type        = list(string)
  default     = ["10.0.8.0/22", "10.0.12.0/22"]
}

variable "tags" {
  description = "Tags chung"
  type        = map(string)
  default     = {}
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token cho ExternalDNS"
  type        = string
  sensitive   = true
  # Khuyen nghi luu token trong terraform.tfvars (file nay da duoc .gitignore bo qua)
  # Hoac dat qua bien moi truong TF_VAR_cloudflare_api_token
  # Neu da co terraform.tfvars thi apply/destroy khong can truyen -var
}
