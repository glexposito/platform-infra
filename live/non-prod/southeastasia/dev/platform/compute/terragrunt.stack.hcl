locals {
  mock_rg_name     = "mock-rg"
  mock_rg_location = "southeastasia"
  mock_rg_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/${local.mock_rg_name}"
}

unit "aca_env" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-env"
  path   = "aca-env"

  values = {
    name                             = "platform"
    log_analytics_retention_in_days = 30
    tags = {
      team    = "core"
      purpose = "poc"
    }
  }

  autoinclude {
    dependency "resource_group" {
      config_path = "${get_repo_root()}/live/non-prod/southeastasia/dev/platform/rg/.terragrunt-stack/rg"

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        resource_group_name     = local.mock_rg_name
        resource_group_location = local.mock_rg_location
        resource_group_id       = local.mock_rg_id
      }
    }
  }
}
