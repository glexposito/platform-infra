include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  region_vars     = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars        = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  subscription_id = get_env("AZURE_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
  env             = local.env_vars.locals.environment
  name            = "myapp"
  statuspage_api_key = trimspace(get_env("STATUSPAGE_API_KEY", ""))
}

terraform {
  source = "../../../../../modules/aca-app"
}

dependency "platform" {
  config_path = "../env-platform"
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs_merge_strategy_with_state  = "shallow"

  mock_outputs = {
    container_app_environment_id = "/subscriptions/${local.subscription_id}/resourceGroups/mock-rg/providers/Microsoft.App/managedEnvironments/mock-cae"
    resource_group_name          = "mock-rg"
  }
}

inputs = {
  container_app_environment_id    = dependency.platform.outputs.container_app_environment_id
  resource_group_name             = dependency.platform.outputs.resource_group_name
  location                        = local.region_vars.locals.location
  environment                     = local.env
  name                            = local.name
  container_app_name              = "ca-${local.name}-${local.env}-${local.region_vars.locals.location_short}"
  container_name                  = local.name
  container_image                 = coalesce(get_env("MYAPP_IMAGE", ""), "ghcr.io/example/myapp:${local.env}")
  registry_server                 = trimspace(get_env("MYAPP_REGISTRY_SERVER", "")) == "" ? null : trimspace(get_env("MYAPP_REGISTRY_SERVER", ""))
  acr_id                          = trimspace(get_env("MYAPP_ACR_ID", "")) == "" ? null : trimspace(get_env("MYAPP_ACR_ID", ""))
  min_replicas                    = 1
  max_replicas                    = 1
  environment_variables = {
    APP_ENV = local.env
  }
  secret_environment_variables = local.statuspage_api_key == "" ? {} : {
    STATUSPAGE_API_KEY = {
      secret_name  = "statuspage-api-key"
      secret_value = local.statuspage_api_key
    }
  }
}
