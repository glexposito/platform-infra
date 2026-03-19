include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  region_vars     = read_terragrunt_config("${get_terragrunt_dir()}/../../../region.hcl")
  app_name        = values.name
  environment     = values.environment
  location        = local.region_vars.locals.location
  location_short  = local.region_vars.locals.location_short
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/aca-app"
}

dependency "platform" {
  config_path = values.platform_path

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs_merge_strategy_with_state  = "shallow"

  mock_outputs = {
    container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.App/managedEnvironments/mock-cae"
    resource_group_name          = "mock-rg"
  }
}

inputs = {
  container_app_environment_id = dependency.platform.outputs.container_app_environment_id
  resource_group_name          = dependency.platform.outputs.resource_group_name
  location                     = local.location
  environment                  = local.environment
  name                         = local.app_name
  container_app_name           = "ca-${local.app_name}-${local.environment}-${local.location_short}"
  container_name               = local.app_name
  container_image              = values.container_image
  registry_server              = try(values.registry_server, null)
  acr_id                       = try(values.acr_id, null)
  min_replicas                 = try(values.min_replicas, 1)
  max_replicas                 = try(values.max_replicas, 1)
  environment_variables = merge(
    {
      APP_ENV = local.environment
    },
    try(values.environment_variables, {})
  )
  secret_environment_variables = try(values.secret_environment_variables, trimspace(get_env("STATUSPAGE_API_KEY", "")) == "" ? {} : {
    STATUSPAGE_API_KEY = {
      secret_name  = "statuspage-api-key"
      secret_value = trimspace(get_env("STATUSPAGE_API_KEY", ""))
    }
  })
}
