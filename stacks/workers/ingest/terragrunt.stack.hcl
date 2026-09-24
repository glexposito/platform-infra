locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars    = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment    = local.env_vars.locals.environment
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short

  aca_env_path = "${get_repo_root()}/live/non-prod/${local.location}/${local.environment}/core/tpm/platform/.terragrunt-stack/aca-env"

  # Shared by every worker in this stack.
  common = {
    resource_group_name            = "rg-workers-${local.environment}-${local.location_short}"
    container_app_environment_name = "cae-workers-${local.environment}-${local.location_short}"
    container_image                = try(values.container_image, "nginxdemos/hello:latest")
    container_cpu                  = try(values.container_cpu, 0.25)
    container_memory               = try(values.container_memory, "0.5Gi")
    min_replicas                   = try(values.min_replicas, 0)
    max_replicas                   = try(values.max_replicas, 1)
    tags                           = try(values.tags, {})
    environment_variables          = try(values.environment_variables, {})
  }
}

unit "ingest-events" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-app"
  path   = "ingest-events"

  autoinclude {
    dependencies {
      paths = [local.aca_env_path]
    }
  }

  # values.workers["ingest-events"] (optional, from the live file) overrides anything above.
  values = merge(local.common, { name = "ingest-events" }, try(values.workers["ingest-events"], {}))
}

unit "ingest-files" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-app"
  path   = "ingest-files"

  autoinclude {
    dependencies {
      paths = [local.aca_env_path]
    }
  }

  # values.workers["ingest-files"] (optional, from the live file) overrides anything above.
  values = merge(local.common, { name = "ingest-files" }, try(values.workers["ingest-files"], {}))
}
