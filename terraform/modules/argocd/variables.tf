variable "release_name" {
  description = "Name of the helm release"
  default     = "argocd"
}

variable "namespace" {
  description = "Namespace to install ArgoCD"
  default     = "argocd"
}

variable "chart_version" {
  description = "Version of the ArgoCD Helm chart"
  default     = "5.51.6"
}

variable "service_type" {
  description = "Service type for ArgoCD server (ClusterIP, NodePort, LoadBalancer)"
  default     = "ClusterIP"
}

variable "values" {
  description = "Additional YAML values to pass to helm_release (optional)"
  default     = ""
}

variable "cluster_name" {
  description = "The name of the EKS cluster (used for cleanup script during destroy)"
  type        = string
}

variable "aws_region" {
  description = "AWS region (used for cleanup script during destroy)"
  type        = string
}
