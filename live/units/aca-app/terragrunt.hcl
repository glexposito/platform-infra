include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars    = read_terragrunt_config("${get_terragrunt_dir()}/../../../../region.hcl")
  app_name       = values.name
  environment    = try(values.environment, local.env_vars.locals.environment)
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/aca-app"
}

inputs = {
  container_app_environment_id   = try(values.container_app_environment_id, null)
  container_app_environment_name = try(values.container_app_environment_name, null)
  resource_group_name            = values.resource_group_name
  location                       = local.location
  environment                    = local.environment
  name                           = local.app_name
  container_app_name             = try(values.container_app_name, "ca-${local.app_name}-${local.environment}-${local.location_short}")
  container_name                 = local.app_name
  container_image                = values.container_image
  registry_server                = try(values.registry_server, null)
  acr_id                         = try(values.acr_id, null)
  min_replicas                   = try(values.min_replicas, 1)
  max_replicas                   = try(values.max_replicas, 1)
  ingress                        = try(values.ingress, null)
  liveness_probes                = try(values.liveness_probes, [])
  readiness_probes               = try(values.readiness_probes, [])
  startup_probes                 = try(values.startup_probes, [])
  environment_variables = merge(
    {
      APP_ENV = local.environment
    },
    try(values.environment_variables, {})
  )
  secret_environment_variables = try(values.secret_environment_variables, {})
}
