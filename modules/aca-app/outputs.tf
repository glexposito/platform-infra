output "container_app_id" {
  description = "Azure Container App ID."
  value       = azurerm_container_app.this.id
}

output "container_app_fqdn" {
  description = "Ingress FQDN, or null when the app has no ingress."
  value       = try(azurerm_container_app.this.ingress[0].fqdn, null)
}

output "identity_id" {
  description = "User-assigned managed identity resource ID."
  value       = module.identity.id
}

output "identity_principal_id" {
  description = "User-assigned managed identity principal ID."
  value       = module.identity.principal_id
}

output "identity_client_id" {
  description = "User-assigned managed identity client ID."
  value       = module.identity.client_id
}
