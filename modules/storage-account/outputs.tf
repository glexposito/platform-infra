output "storage_account_name" {
  description = "Storage account name."
  value       = module.storage_account.name
}

output "storage_account_id" {
  description = "Storage account ID."
  value       = module.storage_account.resource_id
}

output "container_names" {
  description = "Blob container names."
  value       = [for container in module.storage_account.containers : container.name]
}
