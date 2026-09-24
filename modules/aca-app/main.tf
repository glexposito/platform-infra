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
  queue_storage_account_resource_group_name = var.queue_scale == null ? null : coalesce(
    var.queue_scale.storage_account_resource_group_name,
    var.resource_group_name
  )
  service_bus_namespace_resource_group_name = var.service_bus_queue_scale == null ? null : coalesce(
    var.service_bus_queue_scale.namespace_resource_group_name,
    var.resource_group_name
  )
}

data "azurerm_container_app_environment" "existing" {
  count = var.container_app_environment_id == null ? 1 : 0

  name                = var.container_app_environment_name
  resource_group_name = var.resource_group_name
}

data "azurerm_storage_account" "queue_scale" {
  count = var.queue_scale == null ? 0 : 1

  name                = var.queue_scale.storage_account_name
  resource_group_name = local.queue_storage_account_resource_group_name
}

data "azurerm_servicebus_namespace" "service_bus_queue_scale" {
  count = var.service_bus_queue_scale == null ? 0 : 1

  name                = var.service_bus_queue_scale.namespace_name
  resource_group_name = local.service_bus_namespace_resource_group_name
}

module "container_app" {
  source  = "Azure/avm-res-app-containerapp/azurerm"
  version = "~> 0.9.0"

  name                                  = var.container_app_name
  resource_group_name                   = var.resource_group_name
  container_app_environment_resource_id = local.resolved_container_app_environment_id
  revision_mode                         = var.revision_mode
  tags                                  = local.tags

  managed_identities = {
    system_assigned = true
  }

  registries = var.registry_server == null ? null : [
    {
      server   = var.registry_server
      identity = "System"
    }
  ]

  secrets = {
    for key, secret in nonsensitive(var.secret_environment_variables) : key => {
      name                = secret.secret_name
      value               = try(secret.secret_value, null)
      key_vault_secret_id = try(secret.key_vault_secret_id, null)
      identity            = try(secret.key_vault_secret_id, null) == null ? null : "System"
    }
  }

  ingress = var.ingress == null ? null : {
    external_enabled           = var.ingress.external_enabled
    target_port                = var.ingress.target_port
    transport                  = var.ingress.transport
    allow_insecure_connections = var.ingress.allow_insecure_connections

    traffic_weight = [
      {
        latest_revision = true
        percentage      = 100
      }
    ]
  }

  template = {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    azure_queue_scale_rules = var.queue_scale == null ? null : [
      {
        name           = var.queue_scale.rule_name
        account_name   = var.queue_scale.storage_account_name
        queue_name     = var.queue_scale.queue_name
        queue_length   = var.queue_scale.queue_length
        identity       = "system"
        authentication = []
      }
    ]

    custom_scale_rules = var.service_bus_queue_scale == null ? null : [
      {
        name             = var.service_bus_queue_scale.rule_name
        custom_rule_type = "azure-servicebus"
        metadata = {
          namespace    = var.service_bus_queue_scale.namespace_name
          queueName    = var.service_bus_queue_scale.queue_name
          messageCount = tostring(var.service_bus_queue_scale.message_count)
        }
        identity       = "system"
        authentication = []
      }
    ]

    containers = [
      {
        name   = var.container_name
        image  = var.container_image
        cpu    = var.container_cpu
        memory = var.container_memory

        env = concat(
          [for name, value in var.environment_variables : { name = name, value = value }],
          [for name, secret in nonsensitive(var.secret_environment_variables) : { name = name, secret_name = secret.secret_name }]
        )

        liveness_probes = [
          for probe in var.liveness_probes : {
            transport               = probe.transport
            port                    = probe.port
            path                    = probe.path
            host                    = probe.host
            initial_delay           = probe.initial_delay
            interval_seconds        = probe.interval_seconds
            timeout                 = probe.timeout
            failure_count_threshold = probe.failure_count_threshold
            header                  = [for name, value in probe.header : { name = name, value = value }]
          }
        ]

        readiness_probes = [
          for probe in var.readiness_probes : {
            transport               = probe.transport
            port                    = probe.port
            path                    = probe.path
            host                    = probe.host
            initial_delay           = probe.initial_delay
            interval_seconds        = probe.interval_seconds
            timeout                 = probe.timeout
            failure_count_threshold = probe.failure_count_threshold
            header                  = [for name, value in probe.header : { name = name, value = value }]
          }
        ]

        startup_probes = [
          for probe in var.startup_probes : {
            transport               = probe.transport
            port                    = probe.port
            path                    = probe.path
            host                    = probe.host
            initial_delay           = probe.initial_delay
            interval_seconds        = probe.interval_seconds
            timeout                 = probe.timeout
            failure_count_threshold = probe.failure_count_threshold
            header                  = [for name, value in probe.header : { name = name, value = value }]
          }
        ]
      }
    ]
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  count                = var.acr_id == null ? 0 : 1
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.container_app.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_queue_data_reader" {
  count                = var.queue_scale == null ? 0 : 1
  scope                = data.azurerm_storage_account.queue_scale[0].id
  role_definition_name = "Storage Queue Data Reader"
  principal_id         = module.container_app.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_queue_data_message_processor" {
  count                = var.queue_scale == null ? 0 : 1
  scope                = data.azurerm_storage_account.queue_scale[0].id
  role_definition_name = "Storage Queue Data Message Processor"
  principal_id         = module.container_app.identity[0].principal_id
}

resource "azurerm_role_assignment" "service_bus_queue_data_receiver" {
  count = var.service_bus_queue_scale == null ? 0 : 1

  scope                = "${data.azurerm_servicebus_namespace.service_bus_queue_scale[0].id}/queues/${var.service_bus_queue_scale.queue_name}"
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = module.container_app.identity[0].principal_id
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = module.container_app.identity[0].principal_id
}
