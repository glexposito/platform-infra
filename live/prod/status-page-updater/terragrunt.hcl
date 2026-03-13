include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/aca-status-page-updater"
}

inputs = {
  location                       = get_env("AZURE_LOCATION", "australiaeast")
  environment                    = "prod"
  name                           = "status-page-updater"
  resource_group_name            = "rg-status-page-updater-prod"
  container_app_environment_name = "cae-status-page-updater-prod"
  log_analytics_workspace_name   = "law-status-page-updater-prod"
  log_analytics_retention_in_days = 30
  container_app_name             = "ca-status-page-updater-prod"
  container_image                = get_env("STATUS_PAGE_UPDATER_IMAGE", "ghcr.io/example/status-page-updater:prod")
  registry_server                = trimspace(get_env("STATUS_PAGE_UPDATER_REGISTRY_SERVER", "")) == "" ? null : trimspace(get_env("STATUS_PAGE_UPDATER_REGISTRY_SERVER", ""))
  acr_id                         = trimspace(get_env("STATUS_PAGE_UPDATER_ACR_ID", "")) == "" ? null : trimspace(get_env("STATUS_PAGE_UPDATER_ACR_ID", ""))
  min_replicas                   = 1
  max_replicas                   = 1
  environment_variables = {
    APP_ENV = "prod"
  }
  secret_environment_variables = {
    STATUSPAGE_API_KEY = {
      secret_name  = "statuspage-api-key"
      secret_value = get_env("STATUSPAGE_API_KEY", "")
    }
  }
}
