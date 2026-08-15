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
  description = "Namespace Argo CD is installed in. The root Application is created here."
  type        = string
}

variable "app_name" {
  description = "Name of the root (app-of-apps) Application."
  type        = string
  default     = "platform-apps"
}

variable "repo_url" {
  description = "Git URL of the GitOps repo holding platform/app Application manifests. Terraform's job ends here; Argo CD takes over everything under this repo from this point on."
  type        = string
}

variable "repo_path" {
  description = "Path within the GitOps repo the root Application watches."
  type        = string
  default     = "."
}

variable "repo_revision" {
  description = "Git revision (branch, tag) the root Application tracks."
  type        = string
  default     = "main"
}
