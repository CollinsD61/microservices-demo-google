variable "cloudflare_api_token" {
  type        = string
  description = "API Token cho tài khoản Cloudflare (để cập nhật CNAME)"
  sensitive   = true
}

variable "cloudflare_domain" {
  type        = string
  description = "Tên miền cơ sở mà Cloudflare đang quản lý (ví dụ: dohoangdevops.io.vn)"
}
