unit "rg" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/rg"
  path   = "rg"

  values = {
    name = "workers"
  }
}

unit "aca_env" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-env"
  path   = "aca-env"

  values = {
    name                            = "workers"
    log_analytics_retention_in_days = 30
    tags = {
      team = "core"
    }
  }

  autoinclude {
    dependency "resource_group" {
      config_path = "../rg"

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        resource_group_name     = "mock-rg"
        resource_group_location = "southeastasia"
      }
    }
  }
}
