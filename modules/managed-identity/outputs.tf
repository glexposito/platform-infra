output "id" {
  description = "User-assigned managed identity resource ID. Resolves only after every role assignment exists, so resources that attach the identity are created with their access already granted."
  value       = azurerm_user_assigned_identity.this.id

  depends_on = [
    azurerm_role_assignment.this,
    azapi_resource.cosmos_role_assignment,
    azurerm_managed_redis_access_policy_assignment.this,
  ]
}

output "name" {
  description = "User-assigned managed identity name."
  value       = azurerm_user_assigned_identity.this.name
}

output "principal_id" {
  description = "Object (principal) ID of the identity."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  description = "Client ID of the identity. Set AZURE_CLIENT_ID to this so DefaultAzureCredential picks the identity."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "role_assignment_scopes" {
  description = "Resolved target scope of every role assignment, keyed like role_assignments."
  value       = { for key, assignment in local.assignments : key => assignment.scope }
}
