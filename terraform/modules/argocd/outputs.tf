output "namespace" {
  description = "ArgoCD namespace"
  value       = helm_release.argocd.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.argocd.name
}
