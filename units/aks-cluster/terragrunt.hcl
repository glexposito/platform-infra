include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars    = read_terragrunt_config("${get_terragrunt_dir()}/../../../../region.hcl")
  stack_name     = values.name
  environment    = try(values.environment, local.env_vars.locals.environment)
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/aks-cluster"
}

inputs = {
  location                  = dependency.resource_group.outputs.resource_group_location
  environment                = local.environment
  name                       = local.stack_name
  resource_group_name        = dependency.resource_group.outputs.resource_group_name
  cluster_name               = try(values.cluster_name, "aks-${local.stack_name}-${local.environment}-${local.location_short}")
  dns_prefix                 = try(values.dns_prefix, null)
  kubernetes_version         = try(values.kubernetes_version, null)
  sku_tier                   = try(values.sku_tier, "Free")
  default_node_pool          = try(values.default_node_pool, {})
  network_plugin             = try(values.network_plugin, "azure")
  oidc_issuer_enabled        = try(values.oidc_issuer_enabled, false)
  workload_identity_enabled  = try(values.workload_identity_enabled, false)
  automatic_upgrade_channel  = try(values.automatic_upgrade_channel, null)
  node_os_upgrade_channel    = try(values.node_os_upgrade_channel, null)
}
