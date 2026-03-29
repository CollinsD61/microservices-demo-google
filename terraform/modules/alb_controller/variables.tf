variable "cluster_name" {
  type        = string
  description = "Tên của EKS cluster"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN của OIDC Provider"
}

variable "oidc_provider_url" {
  type        = string
  description = "URL của OIDC Provider"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID nơi cụm EKS đang chạy"
}
