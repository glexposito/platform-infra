stack "ingest" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/stacks/workers/ingest"
  path   = "workers"

  values = {
    tags = {
      team = "core"
    }
  }
}
