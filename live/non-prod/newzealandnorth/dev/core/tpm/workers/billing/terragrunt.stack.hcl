stack "billing" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/stacks/workers/billing"
  path   = "workers"

  values = {
    tags = {
      team = "core"
    }
  }
}
