include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env         = local.env_vars.locals.environment
  app_name    = "myapp"
  stack_name  = "${local.app_name}-platform"
}

terraform {
  source = "../../../../../modules/aca-environment"
}

inputs = {
  location                       = local.region_vars.locals.location
  environment                    = local.env
  name                           = local.stack_name
  resource_group_name            = "rg-${local.stack_name}-${local.env}-${local.region_vars.locals.location_short}"
  container_app_environment_name = "cae-${local.stack_name}-${local.env}-${local.region_vars.locals.location_short}"
  log_analytics_workspace_name   = "law-${local.stack_name}-${local.env}-${local.region_vars.locals.location_short}"
  log_analytics_retention_in_days = 30
}
