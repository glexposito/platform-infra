locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)
}

module "log_analytics_workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.5.1"

  name                                      = var.log_analytics_workspace_name
  location                                  = var.location
  resource_group_name                       = var.resource_group_name
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = var.log_analytics_retention_in_days
  log_analytics_workspace_daily_quota_gb    = var.log_analytics_daily_quota_gb
  tags                                      = local.tags
}

module "container_app_environment" {
  source  = "Azure/avm-res-app-managedenvironment/azurerm"
  version = "~> 0.5.0"

  name                = var.container_app_environment_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  # No VNet is configured, so zone redundancy must be off.
  zone_redundant = false

  log_analytics_workspace = {
    resource_id = module.log_analytics_workspace.resource_id
  }

  # The Consumption workload profile is always present on the environment.
  # minimum_count/maximum_count must stay unset for Consumption profiles --
  # the Azure API always returns 0 for them regardless of config, which
  # otherwise causes perpetual drift on every plan.
  workload_profiles = [
    {
      name                  = "Consumption"
      workload_profile_type = "Consumption"
    }
  ]
}

moved {
  from = azurerm_log_analytics_workspace.this
  to   = module.log_analytics_workspace.azurerm_log_analytics_workspace.this
}
