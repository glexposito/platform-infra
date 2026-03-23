locals {
  root_dir = dirname(find_in_parent_folders("root.hcl"))
}

unit "rg" {
  source = "${local.root_dir}/live/units/rg"
  path   = "rg"

  values = {
    environment = "dev"
    name        = "platform-noncritical"
  }
}

unit "aca-env" {
  source = "${local.root_dir}/live/units/aca-env"
  path   = "aca-env"

  values = {
    environment                     = "dev"
    resource_group_path             = "../rg"
    name                            = "platform-noncritical"
    log_analytics_retention_in_days = 30
  }
}
