include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  region_vars     = read_terragrunt_config("${get_terragrunt_dir()}/../../../region.hcl")
  stack_name      = values.name
  environment     = values.environment
  location        = local.region_vars.locals.location
  location_short  = local.region_vars.locals.location_short
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/aca-environment"
}

inputs = {
  location                        = local.location
  environment                     = local.environment
  name                            = local.stack_name
  resource_group_name             = "rg-${local.stack_name}-${local.environment}-${local.location_short}"
  container_app_environment_name  = "cae-${local.stack_name}-${local.environment}-${local.location_short}"
  log_analytics_workspace_name    = "law-${local.stack_name}-${local.environment}-${local.location_short}"
  log_analytics_retention_in_days = try(values.log_analytics_retention_in_days, 30)
}
