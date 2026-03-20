locals {
  root_dir = dirname(find_in_parent_folders("root.hcl"))
}

unit "aca-env" {
  source = "${local.root_dir}/live/units/aca-env"
  path   = "aca-env"

  values = {
    environment                     = "prod"
    name                            = "platform-noncritical"
    log_analytics_retention_in_days = 30
  }
}

unit "myapp-1" {
  source = "${local.root_dir}/live/units/aca-app"
  path   = "myapp-1"

  values = {
    environment     = "prod"
    platform_path   = "../aca-env"
    name            = "myapp-1"
    container_image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    min_replicas    = 1
    max_replicas    = 1
    secret_environment_variables = {
      STATUSPAGE_API_KEY = {
        secret_name  = "statuspage-api-key"
        secret_value = trimspace(get_env("STATUSPAGE_API_KEY", ""))
      }
      # EXTERNAL_API_KEY = {
      #   secret_name         = "external-api-key"
      #   key_vault_secret_id = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault>/secrets/external-api-key"
      # }
    }
  }
}
