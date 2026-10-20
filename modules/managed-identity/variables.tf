variable "name" {
  description = "User-assigned managed identity name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group the identity is created in."
  type        = string
}

variable "location" {
  description = "Azure region for the identity."
  type        = string
}

variable "role_assignments" {
  description = <<-EOT
    Roles to grant the identity, keyed by a stable name.
    Point at the target by name: type (acr, cosmos, key_vault, managed_redis, service_bus, storage_account, or a full provider type such as
    "Microsoft.Sql/servers"),
    name, optional resource_group_name (defaults to the identity's resource group), optional subscription_id (defaults to the provider's
    subscription) and optional child path below the resource,
    for example "queues/jobs" or, for Cosmos DB, "dbs/billing". Or set scope to a full resource ID instead, for example a Terragrunt dependency output.
    role is an Azure RBAC role name, for example "Key Vault Secrets User". On Cosmos DB, "Cosmos DB Built-in Data Reader",
    "Cosmos DB Built-in Data Contributor" or a custom sqlRoleDefinitions ID grants a data-plane role instead. On Azure Managed Redis,
    "Managed Redis Data Access" grants data access through the cache's default access policy.
  EOT
  type = map(object({
    role                = string
    type                = optional(string)
    name                = optional(string)
    resource_group_name = optional(string)
    subscription_id     = optional(string)
    child               = optional(string)
    scope               = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      (assignment.scope != null) != (assignment.type != null && assignment.name != null)
    ])
    error_message = "Each role_assignments entry must set either scope, or both type and name."
  }

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      assignment.type == null || contains(["acr", "cosmos", "key_vault", "managed_redis", "service_bus", "storage_account"], assignment.type) || strcontains(coalesce(assignment.type, ""), "/")
    ])
    error_message = "role_assignments type must be acr, cosmos, key_vault, managed_redis, service_bus, storage_account, or a full provider type such as \"Microsoft.Sql/servers\"."
  }

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      !(contains(["Cosmos DB Built-in Data Reader", "Cosmos DB Built-in Data Contributor"], assignment.role) || strcontains(assignment.role, "/sqlRoleDefinitions/")) ||
      assignment.type == "cosmos" ||
      can(regex("(?i)/providers/Microsoft\\.DocumentDB/databaseAccounts/", coalesce(assignment.scope, "")))
    ])
    error_message = "Cosmos DB data-plane roles require type = \"cosmos\" or a scope inside a Cosmos DB account."
  }

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      assignment.role != "Managed Redis Data Access" || (
        assignment.child == null &&
        (assignment.type == "managed_redis" || can(regex("(?i)/providers/Microsoft\\.Cache/redisEnterprise/[^/]+$", coalesce(assignment.scope, ""))))
      )
    ])
    error_message = "\"Managed Redis Data Access\" requires type = \"managed_redis\" (without child) or a scope that is an Azure Managed Redis resource ID."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
