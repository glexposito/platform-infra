locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)

  containers = {
    for name in var.containers : name => {
      name = name
    }
  }
}

module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.8.1"

  name                      = var.storage_account_name
  parent_id                 = var.resource_group_id
  location                  = var.location
  account_tier              = var.account_tier
  account_replication_type  = var.account_replication_type
  account_kind              = var.account_kind
  min_tls_version           = var.min_tls_version
  containers                = local.containers
  tags                      = local.tags
}
