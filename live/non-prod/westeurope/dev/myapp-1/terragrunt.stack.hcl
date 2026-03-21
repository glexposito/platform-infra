locals {
  root_dir                       = dirname(find_in_parent_folders("root.hcl"))
  region_vars                    = read_terragrunt_config("${dirname(find_in_parent_folders("root.hcl"))}/live/non-prod/westeurope/region.hcl")
  location_short                 = local.region_vars.locals.location_short
  platform_name                  = "platform-noncritical"
  environment                    = "dev"
  resource_group_name            = "rg-${local.platform_name}-${local.environment}-${local.location_short}"
  container_app_environment_name = "cae-${local.platform_name}-${local.environment}-${local.location_short}"
}

unit "myapp-1" {
  source = "${local.root_dir}/live/units/aca-app"
  path   = "app"

  values = {
    environment                    = local.environment
    name                           = "myapp-1"
    container_image                = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    resource_group_name            = local.resource_group_name
    container_app_environment_name = local.container_app_environment_name
    min_replicas                   = 1
    max_replicas                   = 1
    secret_environment_variables = {
      TEST_SECRET = {
        secret_name  = "test-secret"
        secret_value = trimspace(get_env("ARM_TENANT_ID", ""))
      }
    }
  }
}
