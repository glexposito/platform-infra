unit "rg" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/live/units/rg"
  path   = "rg"

  values = {
    name = "platform-noncritical"
  }
}

unit "aca-env" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/live/units/aca-env"
  path   = "aca-env"

  values = {
    resource_group_path             = "../rg"
    name                            = "platform-noncritical"
    log_analytics_retention_in_days = 30
  }
}
