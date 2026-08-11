variable "host" {
  description = "Kubernetes API server endpoint of the target cluster."
  type        = string
}

variable "client_certificate" {
  description = "Client certificate (PEM) for authenticating to the cluster."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Client key (PEM) for authenticating to the cluster."
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM)."
  type        = string
  sensitive   = true
}

variable "namespace" {
  description = "Namespace to install Argo CD into."
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "argo-cd Helm chart version. Check https://github.com/argoproj/argo-helm/releases before changing the default."
  type        = string
  default     = "10.3.2"
}
