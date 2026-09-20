stack "pulse-api" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/stacks/pulse-api"
  path   = "app"

  values = {
    container_cpu    = 0.5
    container_memory = "1Gi"
    max_replicas     = 2
    queue_scale = {
      storage_account_name                = "glexpositotfstate01"
      storage_account_resource_group_name = "rg-aca-terraform-state"
      queue_name                          = "pulse-work"
      queue_length                        = 5
    }
    tags = {
      team    = "core"
      purpose = "poc"
    }
    environment_variables = {
      TEST_MESSAGE = "hello from southeastasia"
    }
  }
}
