locals {
  backend_vars          = read_terragrunt_config(find_in_parent_folders("backend.hcl"))
  state_resource_group  = local.backend_vars.locals.state_resource_group
  state_storage_account = local.backend_vars.locals.state_storage_account
  state_container       = local.backend_vars.locals.state_container

  # Pins the subscription Terraform is allowed to operate against, guarding
  # against an ambient az login/ARM_* context pointed at the wrong
  # subscription. Left unset locally unless ARM_SUBSCRIPTION_ID is exported.
  subscription_id = get_env("ARM_SUBSCRIPTION_ID", "")
}

terraform_version_constraint = "= 1.15.8"

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  features {}
  ${local.subscription_id != "" ? "subscription_id = \"${local.subscription_id}\"" : ""}
}
EOF
}

remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    resource_group_name  = local.state_resource_group
    storage_account_name = local.state_storage_account
    container_name       = local.state_container
    key                  = "platform/${path_relative_to_include()}/terraform.tfstate"
  }
}
