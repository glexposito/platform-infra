locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)
  resolved_container_app_environment_id = (
    var.container_app_environment_id != null
    ? var.container_app_environment_id
    : data.azurerm_container_app_environment.existing[0].id
  )

  # Grants implied by the app's own features, merged with the caller's role_assignments.
  # A null resource_group_name falls back to the app's resource group.
  feature_role_assignments = merge(
    var.acr_id == null ? {} : {
      acr_pull = {
        scope = var.acr_id
        role  = "AcrPull"
      }
    },
    var.queue_scale == null ? {} : {
      storage_queue_data_reader = {
        type                = "storage_account"
        name                = var.queue_scale.storage_account_name
        resource_group_name = var.queue_scale.storage_account_resource_group_name
        role                = "Storage Queue Data Reader"
      }
      storage_queue_data_message_processor = {
        type                = "storage_account"
        name                = var.queue_scale.storage_account_name
        resource_group_name = var.queue_scale.storage_account_resource_group_name
        role                = "Storage Queue Data Message Processor"
      }
    },
    var.service_bus_queue_scale == null ? {} : {
      service_bus_queue_data_receiver = {
        type                = "service_bus"
        name                = var.service_bus_queue_scale.namespace_name
        resource_group_name = var.service_bus_queue_scale.namespace_resource_group_name
        child               = "queues/${var.service_bus_queue_scale.queue_name}"
        role                = "Azure Service Bus Data Receiver"
      }
    },
  )
}

data "azurerm_container_app_environment" "existing" {
  count = var.container_app_environment_id == null ? 1 : 0

  name                = var.container_app_environment_name
  resource_group_name = var.resource_group_name
}

module "identity" {
  source = "../managed-identity"

  name                = var.identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  role_assignments    = merge(local.feature_role_assignments, var.role_assignments)
  tags                = local.tags
}

# Plain azurerm rather than the AVM container app module: the AVM module always
# looks the resource group up by name during plan, so a stack that creates the
# resource group and the app together could not plan before its first apply.
resource "azurerm_container_app" "this" {
  name                         = var.container_app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = local.resolved_container_app_environment_id
  revision_mode                = var.revision_mode
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [module.identity.id]
  }

  dynamic "registry" {
    for_each = var.registry_server == null ? [] : [var.registry_server]

    content {
      server   = registry.value
      identity = module.identity.id
    }
  }

  dynamic "secret" {
    for_each = nonsensitive(var.secret_environment_variables)

    content {
      name                = secret.value.secret_name
      value               = secret.value.secret_value
      key_vault_secret_id = secret.value.key_vault_secret_id
      identity            = secret.value.key_vault_secret_id == null ? null : module.identity.id
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

    # azurerm's azure_queue_scale_rule only supports secret authentication, so
    # the identity-based queue scaler is declared as a custom azure-queue rule.
    dynamic "custom_scale_rule" {
      for_each = var.queue_scale == null ? [] : [var.queue_scale]

      content {
        name             = custom_scale_rule.value.rule_name
        custom_rule_type = "azure-queue"
        identity_id      = module.identity.id
        metadata = {
          accountName = custom_scale_rule.value.storage_account_name
          queueName   = custom_scale_rule.value.queue_name
          queueLength = tostring(custom_scale_rule.value.queue_length)
        }
      }
    }

    dynamic "custom_scale_rule" {
      for_each = var.service_bus_queue_scale == null ? [] : [var.service_bus_queue_scale]

      content {
        name             = custom_scale_rule.value.rule_name
        custom_rule_type = "azure-servicebus"
        identity_id      = module.identity.id
        metadata = {
          namespace    = custom_scale_rule.value.namespace_name
          queueName    = custom_scale_rule.value.queue_name
          messageCount = tostring(custom_scale_rule.value.message_count)
        }
      }
    }

    container {
      name   = var.container_name
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      dynamic "env" {
        for_each = merge({ AZURE_CLIENT_ID = module.identity.client_id }, var.environment_variables)

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
          path                    = liveness_probe.value.path
          host                    = liveness_probe.value.host
          initial_delay           = liveness_probe.value.initial_delay
          interval_seconds        = liveness_probe.value.interval_seconds
          timeout                 = liveness_probe.value.timeout
          failure_count_threshold = liveness_probe.value.failure_count_threshold

          dynamic "header" {
            for_each = liveness_probe.value.header

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
          path                    = readiness_probe.value.path
          host                    = readiness_probe.value.host
          initial_delay           = readiness_probe.value.initial_delay
          interval_seconds        = readiness_probe.value.interval_seconds
          timeout                 = readiness_probe.value.timeout
          failure_count_threshold = readiness_probe.value.failure_count_threshold

          dynamic "header" {
            for_each = readiness_probe.value.header

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
          path                    = startup_probe.value.path
          host                    = startup_probe.value.host
          initial_delay           = startup_probe.value.initial_delay
          interval_seconds        = startup_probe.value.interval_seconds
          timeout                 = startup_probe.value.timeout
          failure_count_threshold = startup_probe.value.failure_count_threshold

          dynamic "header" {
            for_each = startup_probe.value.header

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
