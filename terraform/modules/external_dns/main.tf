resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.14.3"

  # Không block apply chờ pod healthy — ExternalDNS là optional (DNS sync)
  # Pod lỗi sẽ chỉ ảnh hưởng DNS record, không ảnh hưởng infra
  wait    = false
  timeout = 120

  # Chỉ định nhà cung cấp DNS là Cloudflare
  set {
    name  = "provider"
    value = "cloudflare"
  }

  # Cấu hình Token API của Cloudflare
  set {
    name  = "env[0].name"
    value = "CF_API_TOKEN"
  }

  set {
    name  = "env[0].value"
    value = var.cloudflare_api_token
  }

  # Theo dõi các đối tượng Ingress
  set {
    name  = "source[0]"
    value = "ingress"
  }

  # Theo dõi các object Service
  set {
    name  = "source[1]"
    value = "service"
  }

  # Giới hạn việc tạo DNS record chỉ thuộc Zone này để an toàn
  set {
    name  = "domainFilters[0]"
    value = var.cloudflare_domain
  }

  # Cấu hình Annotation Filter nếu muốn ExternalDNS chỉ bắt các Ingress nào có annotation:
  # "external-dns.alpha.kubernetes.io/hostname"
  # Ở đây mình cấu hình cho nó tự bắt tự động hostname không rào buộc rườm rà.
}
