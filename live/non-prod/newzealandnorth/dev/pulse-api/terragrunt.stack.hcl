stack "pulse-api" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/stacks/pulse-api"
  path   = "app"
}
