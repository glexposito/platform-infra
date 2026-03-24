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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/resource-group"
}

inputs = {
  location            = local.location
  environment         = local.environment
  name                = local.stack_name
  resource_group_name = try(values.resource_group_name, "rg-${local.stack_name}-${local.environment}-${local.location_short}")
}
