locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)
}

resource "azurerm_kubernetes_cluster" "this" {
  name                      = var.cluster_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = coalesce(var.dns_prefix, var.cluster_name)
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.sku_tier
  oidc_issuer_enabled       = var.oidc_issuer_enabled
  workload_identity_enabled = var.workload_identity_enabled
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel
  tags                      = local.tags

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                  = var.default_node_pool.name
    vm_size               = var.default_node_pool.vm_size
    node_count            = var.default_node_pool.enable_auto_scaling ? null : var.default_node_pool.node_count
    min_count             = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.min_count : null
    max_count             = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.max_count : null
    auto_scaling_enabled  = var.default_node_pool.enable_auto_scaling
    os_disk_size_gb       = var.default_node_pool.os_disk_size_gb
    orchestrator_version  = var.default_node_pool.orchestrator_version

    upgrade_settings {
      max_surge = var.default_node_pool.upgrade_max_surge
    }
  }

  network_profile {
    network_plugin = var.network_plugin
  }
}
