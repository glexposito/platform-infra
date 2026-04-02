unit "pulse-api" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-app"
  path   = "app"

  values = {
    name                           = "pulse-api"
    resource_group_name            = "rg-platform-nc-dev-sea"
    container_app_environment_name = "cae-platform-nc-dev-sea"
    container_image                = "ghcr.io/glexposito/pulse-api:latest"
    min_replicas                   = 0
    max_replicas                   = 1
    ingress = {
      external_enabled = true
      target_port      = 8080
    }
    liveness_probes = [
      {
        transport        = "HTTP"
        port             = 8080
        path             = "/live"
        initial_delay    = 5
        interval_seconds = 5
      }
    ]
    readiness_probes = [
      {
        transport        = "HTTP"
        port             = 8080
        path             = "/ready"
        initial_delay    = 5
        interval_seconds = 5
      }
    ]
  }
}
