output "id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "identity_principal_id" {
  description = "Principal ID of the cluster's system-assigned managed identity."
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL, used for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "host" {
  description = "Kubernetes API server endpoint."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
}

output "client_certificate" {
  description = "Client certificate (PEM) for authenticating to the cluster."
  value       = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
  sensitive   = true
}

output "client_key" {
  description = "Client key (PEM) for authenticating to the cluster."
  value       = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].client_key)
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM)."
  value       = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  sensitive   = true
}
