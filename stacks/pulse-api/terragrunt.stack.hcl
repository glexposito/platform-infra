locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars    = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment    = local.env_vars.locals.environment
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short
}

unit "pulse-api" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-app"
  path   = "app"

  autoinclude {
    dependencies {
      paths = ["${get_repo_root()}/live/non-prod/${local.location}/${local.environment}/platform/compute/.terragrunt-stack/aca-env"]
    }
  }

  values = {
    name                           = "pulse-api"
    resource_group_name            = "rg-platform-${local.environment}-${local.location_short}"
    container_app_environment_name = "cae-platform-${local.environment}-${local.location_short}"
    container_image                = "ghcr.io/glexposito/pulse-api:latest"
    container_cpu                  = try(values.container_cpu, 0.25)
    container_memory               = try(values.container_memory, "0.5Gi")
    tags                           = try(values.tags, {})
    environment_variables          = try(values.environment_variables, {})
    secret_environment_variables   = try(values.secret_environment_variables, {})
    min_replicas                   = try(values.min_replicas, 0)
    max_replicas                   = try(values.max_replicas, 1)
    queue_scale                    = try(values.queue_scale, null)
    ingress = {
      external_enabled = true
      target_port      = 8080
    }
    liveness_probes = [
      {
        transport        = "HTTP"
        port             = 8080
        path             = "/live"
        initial_delay    = 10
        interval_seconds = 30
      }
    ]
    readiness_probes = [
      {
        transport        = "HTTP"
        port             = 8080
        path             = "/ready"
        initial_delay    = 5
        interval_seconds = 10
      }
    ]
  }
}
