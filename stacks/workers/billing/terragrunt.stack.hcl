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
    role_assignments               = try(values.role_assignments, {})
  }
}

unit "billing-invoices" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-app"
  path   = "billing-invoices"

  autoinclude {
    dependencies {
      paths = [local.aca_env_path]
    }
  }

  # values.workers["billing-invoices"] (optional, from the live file) overrides anything above.
  values = merge(local.common, { name = "billing-invoices" }, try(values.workers["billing-invoices"], {}))
}

unit "billing-payments" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-app"
  path   = "billing-payments"

  autoinclude {
    dependencies {
      paths = [local.aca_env_path]
    }
  }

  # values.workers["billing-payments"] (optional, from the live file) overrides anything above.
  values = merge(local.common, { name = "billing-payments" }, try(values.workers["billing-payments"], {}))
}
