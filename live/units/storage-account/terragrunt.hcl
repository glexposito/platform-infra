include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  region_vars        = read_terragrunt_config("${get_terragrunt_dir()}/../../../../region.hcl")
  stack_name         = values.name
  environment        = values.environment
  location           = local.region_vars.locals.location
  location_short     = local.region_vars.locals.location_short
  storage_name_token = substr(replace(local.stack_name, "-", ""), 0, 13)
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/storage-account"
}

dependency "resource_group" {
  config_path = values.resource_group_path

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs_merge_strategy_with_state  = "shallow"

  mock_outputs = {
    resource_group_name     = "mock-rg"
    resource_group_location = local.location
  }
}

inputs = {
  location                 = dependency.resource_group.outputs.resource_group_location
  environment              = local.environment
  name                     = local.stack_name
  resource_group_name      = dependency.resource_group.outputs.resource_group_name
  storage_account_name     = try(values.storage_account_name, "st${local.storage_name_token}${local.environment}${local.location_short}")
  account_tier             = try(values.account_tier, "Standard")
  account_replication_type = try(values.account_replication_type, "LRS")
  account_kind             = try(values.account_kind, "StorageV2")
  min_tls_version          = try(values.min_tls_version, "TLS1_2")
  containers               = try(values.containers, [])
}
