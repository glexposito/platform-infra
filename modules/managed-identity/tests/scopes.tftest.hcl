mock_provider "azapi" {}

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = { subscription_id = "sub-1" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    override_during = plan
    defaults = {
      id           = "/subscriptions/sub-1/resourceGroups/rg-app/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
      principal_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}

variables {
  name                = "id-test"
  resource_group_name = "rg-app"
  location            = "southeastasia"
  role_assignments = {
    kv           = { type = "key_vault", name = "kv1", role = "Key Vault Secrets User" }
    sb           = { type = "service_bus", name = "sb1", resource_group_name = "rg-other", child = "queues/jobs", role = "Azure Service Bus Data Sender" }
    other_sub    = { type = "key_vault", name = "kv2", resource_group_name = "rg-x", subscription_id = "sub-2", role = "Key Vault Secrets User" }
    sql          = { type = "Microsoft.Sql/servers", name = "sql1", role = "Reader" }
    raw          = { scope = "/subscriptions/x/resourceGroups/y", role = "Reader" }
    cosmos_rbac  = { type = "cosmos", name = "cos1", role = "Cosmos DB Account Reader Role" }
    cosmos_data  = { type = "cosmos", name = "cos1", child = "dbs/db/colls/c", role = "Cosmos DB Built-in Data Reader" }
    cosmos_scope = { scope = "/subscriptions/s2/resourceGroups/r2/providers/Microsoft.DocumentDB/databaseAccounts/cos2", role = "Cosmos DB Built-in Data Contributor" }
    redis_rbac   = { type = "managed_redis", name = "amr1", role = "Reader" }
    redis_data   = { type = "managed_redis", name = "amr1", resource_group_name = "rg-cache", role = "Managed Redis Data Access" }
    redis_scope  = { scope = "/subscriptions/s3/resourceGroups/r3/providers/Microsoft.Cache/redisEnterprise/amr2", role = "Managed Redis Data Access" }
  }
}

run "scopes" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.this["kv"].scope == "/subscriptions/sub-1/resourceGroups/rg-app/providers/Microsoft.KeyVault/vaults/kv1"
    error_message = azurerm_role_assignment.this["kv"].scope
  }
  assert {
    condition     = azurerm_role_assignment.this["sb"].scope == "/subscriptions/sub-1/resourceGroups/rg-other/providers/Microsoft.ServiceBus/namespaces/sb1/queues/jobs"
    error_message = azurerm_role_assignment.this["sb"].scope
  }
  assert {
    condition     = azurerm_role_assignment.this["other_sub"].scope == "/subscriptions/sub-2/resourceGroups/rg-x/providers/Microsoft.KeyVault/vaults/kv2"
    error_message = azurerm_role_assignment.this["other_sub"].scope
  }
  assert {
    condition     = azurerm_role_assignment.this["sql"].scope == "/subscriptions/sub-1/resourceGroups/rg-app/providers/Microsoft.Sql/servers/sql1"
    error_message = azurerm_role_assignment.this["sql"].scope
  }
  assert {
    condition     = azurerm_role_assignment.this["raw"].scope == "/subscriptions/x/resourceGroups/y"
    error_message = azurerm_role_assignment.this["raw"].scope
  }
}

run "cosmos_routing" {
  command = plan

  assert {
    condition     = keys(azurerm_role_assignment.this) == ["cosmos_rbac", "kv", "other_sub", "raw", "redis_rbac", "sb", "sql"]
    error_message = "Azure RBAC assignments: ${jsonencode(keys(azurerm_role_assignment.this))}"
  }
  assert {
    condition     = keys(azapi_resource.cosmos_role_assignment) == ["cosmos_data", "cosmos_scope"]
    error_message = "Cosmos data-plane assignments: ${jsonencode(keys(azapi_resource.cosmos_role_assignment))}"
  }
  assert {
    condition = (
      azapi_resource.cosmos_role_assignment["cosmos_data"].parent_id == "/subscriptions/sub-1/resourceGroups/rg-app/providers/Microsoft.DocumentDB/databaseAccounts/cos1" &&
      azapi_resource.cosmos_role_assignment["cosmos_data"].body.properties.scope == "/subscriptions/sub-1/resourceGroups/rg-app/providers/Microsoft.DocumentDB/databaseAccounts/cos1/dbs/db/colls/c" &&
      azapi_resource.cosmos_role_assignment["cosmos_data"].body.properties.roleDefinitionId == "/subscriptions/sub-1/resourceGroups/rg-app/providers/Microsoft.DocumentDB/databaseAccounts/cos1/sqlRoleDefinitions/00000000-0000-0000-0000-000000000001"
    )
    error_message = jsonencode(azapi_resource.cosmos_role_assignment["cosmos_data"].body)
  }
  assert {
    condition = (
      azapi_resource.cosmos_role_assignment["cosmos_scope"].parent_id == "/subscriptions/s2/resourceGroups/r2/providers/Microsoft.DocumentDB/databaseAccounts/cos2" &&
      azapi_resource.cosmos_role_assignment["cosmos_scope"].body.properties.roleDefinitionId == "/subscriptions/s2/resourceGroups/r2/providers/Microsoft.DocumentDB/databaseAccounts/cos2/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
    )
    error_message = jsonencode(azapi_resource.cosmos_role_assignment["cosmos_scope"].body)
  }
}

run "managed_redis_routing" {
  command = plan

  assert {
    condition     = keys(azurerm_managed_redis_access_policy_assignment.this) == ["redis_data", "redis_scope"]
    error_message = "Managed Redis assignments: ${jsonencode(keys(azurerm_managed_redis_access_policy_assignment.this))}"
  }
  assert {
    condition = (
      azurerm_managed_redis_access_policy_assignment.this["redis_data"].managed_redis_id == "/subscriptions/sub-1/resourceGroups/rg-cache/providers/Microsoft.Cache/redisEnterprise/amr1" &&
      azurerm_managed_redis_access_policy_assignment.this["redis_data"].object_id == "11111111-1111-1111-1111-111111111111" &&
      azurerm_managed_redis_access_policy_assignment.this["redis_scope"].managed_redis_id == "/subscriptions/s3/resourceGroups/r3/providers/Microsoft.Cache/redisEnterprise/amr2"
    )
    error_message = jsonencode(azurerm_managed_redis_access_policy_assignment.this)
  }
  assert {
    condition     = azurerm_role_assignment.this["redis_rbac"].scope == "/subscriptions/sub-1/resourceGroups/rg-app/providers/Microsoft.Cache/redisEnterprise/amr1"
    error_message = azurerm_role_assignment.this["redis_rbac"].scope
  }
}

run "rejects_redis_role_outside_managed_redis" {
  command = plan

  variables {
    role_assignments = { bad = { type = "key_vault", name = "kv1", role = "Managed Redis Data Access" } }
  }

  expect_failures = [var.role_assignments]
}

run "rejects_scope_and_name" {
  command = plan

  variables {
    role_assignments = { bad = { scope = "/x", type = "key_vault", name = "kv1", role = "Reader" } }
  }

  expect_failures = [var.role_assignments]
}

run "rejects_cosmos_role_outside_cosmos" {
  command = plan

  variables {
    role_assignments = { bad = { type = "key_vault", name = "kv1", role = "Cosmos DB Built-in Data Reader" } }
  }

  expect_failures = [var.role_assignments]
}
