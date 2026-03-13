include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  region_short = local.region_vars.locals.location == "australiaeast" ? "aue" : local.region_vars.locals.location == "southeastasia" ? "sea" : "unknown"
  env          = local.env_vars.locals.environment
}

terraform {
  source = "../../../../../modules/aca-status-page-updater"
}

inputs = {
  location                       = local.region_vars.locals.location
  environment                    = local.env
  name                           = "spu"
  resource_group_name            = "rg-spu-${local.env}-${local.region_short}"
  container_app_environment_name = "cae-spu-${local.env}-${local.region_short}"
  log_analytics_workspace_name   = "law-spu-${local.env}-${local.region_short}"
  log_analytics_retention_in_days = 30
  container_app_name             = "ca-spu-${local.env}-${local.region_short}"
  container_image                = get_env("STATUS_PAGE_UPDATER_IMAGE", "ghcr.io/example/status-page-updater:${local.env}")
  registry_server                = trimspace(get_env("STATUS_PAGE_UPDATER_REGISTRY_SERVER", "")) == "" ? null : trimspace(get_env("STATUS_PAGE_UPDATER_REGISTRY_SERVER", ""))
  acr_id                         = trimspace(get_env("STATUS_PAGE_UPDATER_ACR_ID", "")) == "" ? null : trimspace(get_env("STATUS_PAGE_UPDATER_ACR_ID", ""))
  min_replicas                   = 1
  max_replicas                   = 1
  environment_variables = {
    APP_ENV = local.env
  }
  secret_environment_variables = {
    STATUSPAGE_API_KEY = {
      secret_name  = "statuspage-api-key"
      secret_value = get_env("STATUSPAGE_API_KEY", "")
    }
  }
}
