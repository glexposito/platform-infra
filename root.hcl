locals {
  backend_vars          = read_terragrunt_config(find_in_parent_folders("backend.hcl"))
  state_resource_group  = local.backend_vars.locals.state_resource_group
  state_storage_account = local.backend_vars.locals.state_storage_account
  state_container       = local.backend_vars.locals.state_container
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  features {}
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
