locals {
  backend_vars          = read_terragrunt_config(find_in_parent_folders("backend.hcl"))
  subscription_id       = get_env("AZURE_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
  tenant_id             = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")
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
  subscription_id = "${local.subscription_id}"
  tenant_id       = "${local.tenant_id}"
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
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}
