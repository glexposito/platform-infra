stack "pulse-api" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/stacks/pulse-api"
  path   = "app"

  values = {
    container_cpu    = 0.5
    container_memory = "1Gi"
  }
}
