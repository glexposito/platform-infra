locals {
  root_dir        = dirname(find_in_parent_folders("root.hcl"))
  subscription_id = get_env("AZURE_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
}

unit "app-env" {
  source = "${local.root_dir}/live/units/app-env"
  path   = "app-env"

  values = {
    environment                     = "prod"
    name                            = "core"
    log_analytics_retention_in_days = 30
  }
}

unit "myapp" {
  source = "${local.root_dir}/live/units/myapp"
  path   = "myapp"

  values = {
    environment     = "prod"
    subscription_id = local.subscription_id
    platform_path   = "../app-env"
    name            = "myapp"
    container_image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    min_replicas    = 1
    max_replicas    = 1
  }
}
