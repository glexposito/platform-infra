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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/aca-environment"
}

inputs = {
  location                        = dependency.resource_group.outputs.resource_group_location
  environment                     = local.environment
  name                            = local.stack_name
  resource_group_name             = dependency.resource_group.outputs.resource_group_name
  container_app_environment_name  = try(values.container_app_environment_name, "cae-${local.stack_name}-${local.environment}-${local.location_short}")
  log_analytics_workspace_name    = try(values.log_analytics_workspace_name, "law-${local.stack_name}-${local.environment}-${local.location_short}")
  log_analytics_retention_in_days = try(values.log_analytics_retention_in_days, 30)
}
