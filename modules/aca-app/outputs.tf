output "container_app_id" {
  description = "Azure Container App ID."
  value       = module.container_app.resource_id
}

output "container_app_identity_principal_id" {
  description = "System-assigned managed identity principal ID."
  value       = try(module.container_app.identity[0].principal_id, null)
}
