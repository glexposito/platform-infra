unit "myapp-1" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/live/units/aca-app"
  path   = "app"

  values = {
    name                           = "myapp-1"
    resource_group_name            = "rg-platform-noncritical-dev-weu"
    container_app_environment_name = "cae-platform-noncritical-dev-weu"
    container_image                = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    min_replicas                   = 1
    max_replicas                   = 1
    liveness_probes = [
      {
        transport        = "HTTP"
        port             = 8080
        path             = "/"
        initial_delay    = 10
        interval_seconds = 30
      }
    ]
    readiness_probes = [
      {
        transport        = "HTTP"
        port             = 8080
        path             = "/"
        initial_delay    = 5
        interval_seconds = 15
      }
    ]
  }
}
