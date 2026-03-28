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

  set {
    name  = "server.service.type"
    value = var.service_type
  }

  # Additional values can be passed here
  values = var.values != "" ? [var.values] : []
}

# =============================================================================
# CLEANUP PROVISIONER (Xử lý lỗi chặn xóa Destroy EKS)
# =============================================================================

resource "null_resource" "cleanup_argocd_apps" {
  # Chạy script shell dọn dẹp trước khi Helm release bị xóa
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "Update kubeconfig to connect to EKS cluster for cleanup..."
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || true
      
      echo "Deleting all ArgoCD applications to cascade delete AWS resources (LoadBalancers, Volumes, Ingresses)..."
      kubectl delete applications.argoproj.io --all -n argocd --ignore-not-found || true
      
      echo "Force deleting stuck ingresses and loadbalancer services..."
      kubectl delete ingress --all --all-namespaces --ignore-not-found || true
      kubectl delete svc --all --all-namespaces -l "kubernetes.io/service.name" || true
      
      echo "Waiting 15 seconds for AWS to detach and delete Network Interfaces / LoadBalancers..."
      sleep 15
    EOT
  }

  triggers = {
    cluster_name = var.cluster_name
    region       = var.aws_region
  }

  depends_on = [helm_release.argocd]
}
