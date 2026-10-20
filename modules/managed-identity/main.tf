data "azurerm_client_config" "current" {}

locals {
  subscription_id = data.azurerm_client_config.current.subscription_id

  # Short aliases accepted as role_assignments type. Any full provider type
  # such as "Microsoft.Sql/servers" is accepted as-is.
  resource_types = {
    acr             = "Microsoft.ContainerRegistry/registries"
    cosmos          = "Microsoft.DocumentDB/databaseAccounts"
    key_vault       = "Microsoft.KeyVault/vaults"
    managed_redis   = "Microsoft.Cache/redisEnterprise"
    service_bus     = "Microsoft.ServiceBus/namespaces"
    storage_account = "Microsoft.Storage/storageAccounts"
  }

  # Built-in Cosmos DB data-plane roles. These are not Azure RBAC roles and
  # are granted with a Cosmos sqlRoleAssignment instead.
  cosmos_builtin_role_ids = {
    "Cosmos DB Built-in Data Reader"      = "00000000-0000-0000-0000-000000000001"
    "Cosmos DB Built-in Data Contributor" = "00000000-0000-0000-0000-000000000002"
  }

  # Azure Managed Redis data access is an access policy assignment, not Azure
  # RBAC. The assignment always grants the database's default (full) policy,
  # so this is the only Redis data role.
  managed_redis_data_role = "Managed Redis Data Access"

  assignments = {
    for key, assignment in var.role_assignments : key => {
      role = assignment.role
      scope = assignment.scope != null ? assignment.scope : join("/", compact([
        "/subscriptions/${coalesce(assignment.subscription_id, local.subscription_id)}/resourceGroups/${coalesce(assignment.resource_group_name, var.resource_group_name)}",
        "providers/${lookup(local.resource_types, assignment.type, assignment.type)}/${assignment.name}",
        assignment.child,
      ]))
      # A built-in Cosmos data-plane role name, or a custom sqlRoleDefinitions ID.
      cosmos_data_plane        = contains(keys(local.cosmos_builtin_role_ids), assignment.role) || strcontains(assignment.role, "/sqlRoleDefinitions/")
      managed_redis_data_plane = assignment.role == local.managed_redis_data_role
    }
  }

  rbac_role_assignments = {
    for key, assignment in local.assignments : key => assignment if !assignment.cosmos_data_plane && !assignment.managed_redis_data_plane
  }

  cosmos_role_assignments = {
    for key, assignment in local.assignments : key => merge(assignment, {
      account_id = regex("(?i)^(.*/providers/Microsoft\\.DocumentDB/databaseAccounts/[^/]+)", assignment.scope)[0]
    }) if assignment.cosmos_data_plane
  }

  managed_redis_access_policy_assignments = {
    for key, assignment in local.assignments : key => assignment if assignment.managed_redis_data_plane
  }
}

resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "this" {
  for_each = local.rbac_role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  principal_type       = "ServicePrincipal"
}

# azapi rather than azurerm_cosmosdb_sql_role_assignment: the azurerm resource
# only takes an account name and resource group, so it cannot reach an account
# in another subscription.
resource "azapi_resource" "cosmos_role_assignment" {
  for_each = local.cosmos_role_assignments

  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15"
  parent_id = each.value.account_id
  # Stable GUID; a new scope or role yields a new assignment rather than an in-place update.
  name = uuidv5("url", "${var.name}/${each.key}/${each.value.scope}/${each.value.role}")

  body = {
    properties = {
      principalId      = azurerm_user_assigned_identity.this.principal_id
      roleDefinitionId = strcontains(each.value.role, "/") ? each.value.role : "${each.value.account_id}/sqlRoleDefinitions/${local.cosmos_builtin_role_ids[each.value.role]}"
      scope            = each.value.scope
    }
  }
}

resource "azurerm_managed_redis_access_policy_assignment" "this" {
  for_each = local.managed_redis_access_policy_assignments

  managed_redis_id = each.value.scope
  object_id        = azurerm_user_assigned_identity.this.principal_id
}
