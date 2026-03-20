locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)
}

resource "azurerm_container_app" "this" {
  name                         = var.container_app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = var.revision_mode
  tags                         = local.tags

  identity {
    type = "SystemAssigned"
  }

  dynamic "registry" {
    for_each = var.registry_server == null ? [] : [var.registry_server]
    content {
      server   = registry.value
      identity = "System"
    }
  }

  dynamic "secret" {
    for_each = nonsensitive(var.secret_environment_variables)
    content {
      name                = secret.value.secret_name
      value               = try(secret.value.secret_value, null)
      key_vault_secret_id = try(secret.value.key_vault_secret_id, null)
      identity            = try(secret.value.key_vault_secret_id, null) == null ? null : "System"
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.container_name
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = nonsensitive(var.secret_environment_variables)
        content {
          name        = env.key
          secret_name = env.value.secret_name
        }
      }
    }
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  count                = var.acr_id == null ? 0 : 1
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.this.identity[0].principal_id
}
