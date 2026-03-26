include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars    = read_terragrunt_config("${get_terragrunt_dir()}/../../../../region.hcl")
  app_name       = values.name
  environment    = try(values.environment, local.env_vars.locals.environment)
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short
  default_container = {
    name   = local.app_name
    image  = values.container_image
    cpu    = try(values.container_cpu, 0.5)
    memory = try(values.container_memory, 1.0)
    ports  = try(values.container_ports, [])
    environment_variables = merge(
      {
        APP_ENV = local.environment
      },
      try(values.environment_variables, {})
    )
    secure_environment_variables = try(values.secure_environment_variables, {})
    commands                     = try(values.commands, [])
    readiness_probe              = try(values.readiness_probe, null)
    liveness_probe               = try(values.liveness_probe, null)
  }
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/aci-app"
}

inputs = {
  location                  = local.location
  environment               = local.environment
  name                      = local.app_name
  resource_group_name       = values.resource_group_name
  container_group_name      = try(values.container_group_name, "ci-${local.app_name}-${local.environment}-${local.location_short}")
  os_type                   = try(values.os_type, "Linux")
  restart_policy            = try(values.restart_policy, "Always")
  ip_address_type           = try(values.ip_address_type, "None")
  dns_name_label            = try(values.dns_name_label, null)
  subnet_ids                = try(values.subnet_ids, null)
  containers                = try(values.containers, [local.default_container])
  image_registry_credential = try(values.image_registry_credential, null)
}
