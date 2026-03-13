locals {
  subscription_id       = get_env("AZURE_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
  tenant_id             = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")
  state_resource_group  = get_env("TG_STATE_RESOURCE_GROUP", "rg-aca-terraform-state")
  state_storage_account = get_env("TG_STATE_STORAGE_ACCOUNT", "acatfstate")
  state_container       = get_env("TG_STATE_CONTAINER", "tfstate")
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
