# =============================================================================
# ECR MODULE VARIABLES
# =============================================================================

variable "project_name" {
  description = "Tên project, dùng làm prefix cho ECR repos"
  type        = string
  default     = "online-boutique"
}

variable "repository_list" {
  description = "Danh sách các microservices cần tạo repo"
  type        = list(string)
  default = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice",
    "loadgenerator"
  ]
}

variable "image_tag_mutability" {
  description = "MUTABLE hoặc IMMUTABLE - IMMUTABLE an toàn hơn cho production"
  type        = string
  default     = "MUTABLE"
}

variable "encryption_type" {
  description = "Loại mã hóa: AES256 (miễn phí) hoặc KMS (có phí)"
  type        = string
  default     = "AES256"
}

variable "kms_key_arn" {
  description = "KMS Key ARN nếu dùng encryption_type = KMS"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Tối ưu chi phí - Số lượng images giữ lại
# -----------------------------------------------------------------------------

variable "prod_image_count" {
  description = "Số lượng production images giữ lại (nhiều hơn để rollback)"
  type        = number
  default     = 15
}

variable "dev_image_count" {
  description = "Số lượng dev images giữ lại (ít hơn để tiết kiệm)"
  type        = number
  default     = 5
}

variable "max_image_age_days" {
  description = "Xóa images cũ hơn N ngày"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags chung cho tất cả resources"
  type        = map(string)
  default = {
    Project   = "OnlineBoutique"
    ManagedBy = "Terraform"
  }
}
