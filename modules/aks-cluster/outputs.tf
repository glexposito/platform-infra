locals {
  kubeconfig = yamldecode(module.aks.kube_config)
}

output "id" {
  description = "AKS cluster resource ID."
  value       = module.aks.resource_id
}

output "name" {
  description = "AKS cluster name."
  value       = module.aks.name
}

output "identity_principal_id" {
  description = "Principal ID of the cluster's system-assigned managed identity."
  value       = module.aks.identity_principal_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL, used for workload identity federation."
  value       = module.aks.oidc_issuer_profile_issuer_url
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster."
  value       = module.aks.kube_config
  sensitive   = true
}

output "host" {
  description = "Kubernetes API server endpoint."
  value       = local.kubeconfig.clusters[0].cluster.server
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate (PEM) for authenticating to the cluster."
  value       = base64decode(local.kubeconfig.users[0].user.client-certificate-data)
  sensitive   = true
}

output "client_key" {
  description = "Client key (PEM) for authenticating to the cluster."
  value       = base64decode(local.kubeconfig.users[0].user.client-key-data)
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM)."
  value       = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
  sensitive   = true
}
