# =============================================================================
# ARGOCD HELM RELEASE
# =============================================================================

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}


resource "helm_release" "argocd" {
  name             = var.release_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = var.namespace
  create_namespace = true
  version          = var.chart_version
  wait             = false
  timeout          = 120

  set {
    name  = "server.service.type"
    value = var.service_type
  }

  # Additional values can be passed here
  values = var.values != "" ? [var.values] : []
}

# =============================================================================
# CLEANUP PROVISIONER - Xóa ArgoCD Application objects trước khi helm uninstall
# NOTE: Cleanup ALB/SG/ENI được xử lý bởi null_resource.pre_destroy_cleanup
#       ở cấp environment (environments/dev/main.tf) — chạy trước resource này.
# =============================================================================

resource "null_resource" "cleanup_argocd_apps" {
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-Command"]
    command     = <<EOT
      Write-Host "[ArgoCD Cleanup] Connecting to EKS cluster..." -ForegroundColor Cyan
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} 2>&1 | Out-Null

      if ($LASTEXITCODE -eq 0) {
        Write-Host "[ArgoCD Cleanup] Deleting ArgoCD Application objects (prevent re-creation during helm uninstall)..." -ForegroundColor Cyan
        kubectl patch applications.argoproj.io --all -n argocd --type=merge -p '{"metadata":{"finalizers":[]}}' --request-timeout=15s 2>&1 | Out-Null
        kubectl patch appprojects.argoproj.io --all -n argocd --type=merge -p '{"metadata":{"finalizers":[]}}' --request-timeout=15s 2>&1 | Out-Null
        kubectl delete applications.argoproj.io --all -n argocd --ignore-not-found --wait=false --request-timeout=15s 2>&1 | Out-Null
        kubectl delete appprojects.argoproj.io --all -n argocd --ignore-not-found --wait=false --request-timeout=15s 2>&1 | Out-Null
        Write-Host "[ArgoCD Cleanup] Deleting ArgoCD CRDs to keep cluster fully clean..." -ForegroundColor Cyan
        kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io --ignore-not-found --wait=false --request-timeout=15s 2>&1 | Out-Null
        Write-Host "[ArgoCD Cleanup] Done." -ForegroundColor Green
      } else {
        Write-Warning "[ArgoCD Cleanup] Could not connect to EKS — skipping."
      }
    EOT
  }

  triggers = {
    cluster_name = var.cluster_name
    region       = var.aws_region
  }

  depends_on = [helm_release.argocd]
}
