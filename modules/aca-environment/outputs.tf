output "resource_group_name" {
  description = "Resource group containing the deployment."
  value       = var.resource_group_name
}

output "resource_group_location" {
  description = "Resource group location."
  value       = var.location
}

output "container_app_environment_id" {
  description = "Azure Container Apps environment ID."
  value       = module.container_app_environment.resource_id
}
