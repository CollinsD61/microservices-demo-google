# =============================================================================
# SHARED RESOURCES VARIABLES
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

variable "repository_list" {
  description = "Danh sách microservices"
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
