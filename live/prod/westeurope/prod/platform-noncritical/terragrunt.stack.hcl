locals {
  root_dir = dirname(find_in_parent_folders("root.hcl"))
}

unit "rg" {
  source = "${local.root_dir}/live/units/rg"
  path   = "rg"

  values = {
    environment = "prod"
    name        = "platform-noncritical"
  }
}

unit "storage-account" {
  source = "${local.root_dir}/live/units/storage-account"
  path   = "storage-account"

  values = {
    environment          = "prod"
    resource_group_path  = "../rg"
    name                 = "platform-noncritical"
    storage_account_name = "stplatformnoncprodweu"
    containers           = ["tfstate"]
  }
}

unit "aca-env" {
  source = "${local.root_dir}/live/units/aca-env"
  path   = "aca-env"

  values = {
    environment                     = "prod"
    resource_group_path             = "../rg"
    name                            = "platform-noncritical"
    log_analytics_retention_in_days = 30
  }
}
