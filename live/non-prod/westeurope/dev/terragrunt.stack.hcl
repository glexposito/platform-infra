locals {
  root_dir = dirname(find_in_parent_folders("root.hcl"))
}

unit "app-env" {
  source = "${local.root_dir}/live/units/app-env"
  path   = "app-env"

  values = {
    environment                     = "dev"
    name                            = "core"
    log_analytics_retention_in_days = 30
  }
}

unit "myapp" {
  source = "${local.root_dir}/live/units/myapp"
  path   = "myapp"

  values = {
    environment     = "dev"
    platform_path   = "../app-env"
    name            = "myapp"
    container_image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    registry_server = null
    acr_id          = null
    min_replicas    = 1
    max_replicas    = 1
  }
}
