locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.4.0"

  # AVM modules send usage telemetry to Microsoft unless disabled.
  enable_telemetry = false

  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}
