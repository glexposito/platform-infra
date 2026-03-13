output "container_app_id" {
  description = "Azure Container App ID."
  value       = azurerm_container_app.this.id
}

output "container_app_identity_principal_id" {
  description = "System-assigned managed identity principal ID."
  value       = try(azurerm_container_app.this.identity[0].principal_id, null)
}
