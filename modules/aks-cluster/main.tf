locals {
  default_tags = {
    app         = var.name
    environment = var.environment
    managed_by  = "terraform"
  }
  tags = merge(var.tags, local.default_tags)
}

module "aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "~> 0.8.1"

  name                = var.cluster_name
  parent_id           = var.resource_group_id
  location            = var.location
  dns_prefix          = coalesce(var.dns_prefix, var.cluster_name)
  kubernetes_version  = var.kubernetes_version
  tags                = local.tags

  managed_identities = {
    system_assigned = true
  }

  sku = {
    tier = var.sku_tier
    name = "Base"
  }

  oidc_issuer_profile = {
    enabled = var.oidc_issuer_enabled
  }

  security_profile = {
    workload_identity = {
      enabled = var.workload_identity_enabled
    }
  }

  auto_upgrade_profile = var.automatic_upgrade_channel == null && var.node_os_upgrade_channel == null ? null : {
    upgrade_channel         = var.automatic_upgrade_channel
    node_os_upgrade_channel = var.node_os_upgrade_channel
  }

  network_profile = {
    network_plugin = var.network_plugin
  }

  default_agent_pool = {
    name                 = var.default_node_pool.name
    vm_size              = var.default_node_pool.vm_size
    count_of             = var.default_node_pool.enable_auto_scaling ? null : var.default_node_pool.node_count
    min_count            = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.min_count : null
    max_count            = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.max_count : null
    enable_auto_scaling  = var.default_node_pool.enable_auto_scaling
    os_disk_size_gb      = var.default_node_pool.os_disk_size_gb
    orchestrator_version = var.default_node_pool.orchestrator_version

    upgrade_settings = {
      max_surge = var.default_node_pool.upgrade_max_surge
    }
  }
}
