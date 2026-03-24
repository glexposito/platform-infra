unit "myapp-3" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/live/units/aca-app"
  path   = "app"

  values = {
    name                           = "myapp-3"
    resource_group_name            = "rg-platform-noncritical-dev-weu"
    container_app_environment_name = "cae-platform-noncritical-dev-weu"
    container_image                = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    min_replicas                   = 0
    max_replicas                   = 1
  }
}
