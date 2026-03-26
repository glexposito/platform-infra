locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)
  resolved_container_app_environment_id = coalesce(
    var.container_app_environment_id,
    data.azurerm_container_app_environment.existing[0].id
  )
}

data "azurerm_container_app_environment" "existing" {
  count = var.container_app_environment_id == null ? 1 : 0

  name                = var.container_app_environment_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_container_app" "this" {
  name                         = var.container_app_name
  container_app_environment_id = local.resolved_container_app_environment_id
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

  dynamic "ingress" {
    for_each = var.ingress == null ? [] : [var.ingress]
    content {
      external_enabled           = ingress.value.external_enabled
      target_port                = ingress.value.target_port
      transport                  = ingress.value.transport
      allow_insecure_connections = ingress.value.allow_insecure_connections

      traffic_weight {
        latest_revision = true
        percentage      = 100
      }
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

      dynamic "liveness_probe" {
        for_each = var.liveness_probes
        content {
          transport               = liveness_probe.value.transport
          port                    = liveness_probe.value.port
          path                    = try(liveness_probe.value.path, null)
          host                    = try(liveness_probe.value.host, null)
          initial_delay           = try(liveness_probe.value.initial_delay, null)
          interval_seconds        = try(liveness_probe.value.interval_seconds, null)
          timeout                 = try(liveness_probe.value.timeout, null)
          failure_count_threshold = try(liveness_probe.value.failure_count_threshold, null)

          dynamic "header" {
            for_each = try(liveness_probe.value.header, {})
            content {
              name  = header.key
              value = header.value
            }
          }
        }
      }

      dynamic "readiness_probe" {
        for_each = var.readiness_probes
        content {
          transport               = readiness_probe.value.transport
          port                    = readiness_probe.value.port
          path                    = try(readiness_probe.value.path, null)
          host                    = try(readiness_probe.value.host, null)
          initial_delay           = try(readiness_probe.value.initial_delay, null)
          interval_seconds        = try(readiness_probe.value.interval_seconds, null)
          timeout                 = try(readiness_probe.value.timeout, null)
          failure_count_threshold = try(readiness_probe.value.failure_count_threshold, null)

          dynamic "header" {
            for_each = try(readiness_probe.value.header, {})
            content {
              name  = header.key
              value = header.value
            }
          }
        }
      }

      dynamic "startup_probe" {
        for_each = var.startup_probes
        content {
          transport               = startup_probe.value.transport
          port                    = startup_probe.value.port
          path                    = try(startup_probe.value.path, null)
          host                    = try(startup_probe.value.host, null)
          initial_delay           = try(startup_probe.value.initial_delay, null)
          interval_seconds        = try(startup_probe.value.interval_seconds, null)
          timeout                 = try(startup_probe.value.timeout, null)
          failure_count_threshold = try(startup_probe.value.failure_count_threshold, null)

          dynamic "header" {
            for_each = try(startup_probe.value.header, {})
            content {
              name  = header.key
              value = header.value
            }
          }
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
