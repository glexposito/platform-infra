unit "rg" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/rg"
  path   = "rg"

  values = {
    name = "engagement"
  }
}

unit "aca_env" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-env"
  path   = "aca-env"

  values = {
    name = "engagement"
    # No Log Analytics workspace: logs are streamed live only, not stored.
    log_analytics_enabled = false
    tags = {
      team = "engagement"
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

unit "engagement-api" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-app"
  path   = "api"

  values = {
    name            = "engagement-api"
    container_image = "nginx:alpine"
    min_replicas    = 0
    max_replicas    = 1
    tags = {
      team = "engagement"
    }

    # Managed identity smoke test: read-only access to one blob container,
    # deliberately not the whole account, which also holds Terraform state.
    role_assignments = {
      demo_blobs = {
        type                = "storage_account"
        name                = "glexpositotfstate01"
        resource_group_name = "rg-aca-terraform-state"
        child               = "blobServices/default/containers/engagement-demo"
        role                = "Storage Blob Data Reader"
      }
    }
    ingress = {
      external_enabled = true
      target_port      = 80
    }
    liveness_probes = [
      {
        transport        = "HTTP"
        port             = 80
        path             = "/"
        initial_delay    = 5
        interval_seconds = 30
      }
    ]
    readiness_probes = [
      {
        transport        = "HTTP"
        port             = 80
        path             = "/"
        initial_delay    = 2
        interval_seconds = 10
      }
    ]
  }

  autoinclude {
    dependency "aca_env" {
      config_path = "../aca-env"

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        resource_group_name          = "mock-rg"
        container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.App/managedEnvironments/mock-cae"
      }
    }

    inputs = {
      resource_group_name          = dependency.aca_env.outputs.resource_group_name
      container_app_environment_id = dependency.aca_env.outputs.container_app_environment_id
    }
  }
}
