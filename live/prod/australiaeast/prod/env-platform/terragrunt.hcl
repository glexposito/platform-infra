include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env          = local.env_vars.locals.environment
}

terraform {
  source = "../../../../../modules/aca-environment"
}

inputs = {
  location                       = local.region_vars.locals.location
  environment                    = local.env
  name                           = "platform"
  resource_group_name            = "rg-platform-${local.env}-${local.region_vars.locals.location_short}"
  container_app_environment_name = "cae-platform-${local.env}-${local.region_vars.locals.location_short}"
  log_analytics_workspace_name   = "law-platform-${local.env}-${local.region_vars.locals.location_short}"
  log_analytics_retention_in_days = 30
}
