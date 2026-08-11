include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars    = read_terragrunt_config("${get_terragrunt_dir()}/../../../region.hcl")
  stack_name     = "platform-nc"
  environment    = local.env_vars.locals.environment
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/aks-cluster"
}

dependency "resource_group" {
  config_path = "../rg"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs_merge_strategy_with_state  = "shallow"

  mock_outputs = {
    resource_group_name     = "mock-rg"
    resource_group_location = local.location
  }
}

inputs = {
  location             = dependency.resource_group.outputs.resource_group_location
  environment           = local.environment
  name                  = local.stack_name
  resource_group_name   = dependency.resource_group.outputs.resource_group_name
  cluster_name          = "aks-${local.stack_name}-${local.environment}-${local.location_short}"
  dns_prefix             = null
  kubernetes_version     = "1.36"
  sku_tier               = "Free"
  default_node_pool = {
    name                  = "system"
    vm_size               = "Standard_B2s"
    node_count            = 1
    orchestrator_version  = "1.36"
  }
  network_plugin             = "azure"
  oidc_issuer_enabled        = false
  workload_identity_enabled  = false
  automatic_upgrade_channel  = null
  node_os_upgrade_channel    = null
}
