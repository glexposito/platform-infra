locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = local.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = var.container_app_environment_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = local.tags

  # The Consumption workload profile is always present on the environment.
  # minimum_count/maximum_count must stay unset for Consumption profiles --
  # the Azure API always returns 0 for them regardless of config, which
  # otherwise causes perpetual drift on every plan.
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}
