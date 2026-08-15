locals {
  mock_rg_name     = "mock-rg"
  mock_rg_location = "southeastasia"
  mock_rg_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/${local.mock_rg_name}"

  mock_aks_host                   = "https://mock-aks.example.com"
  mock_aks_client_certificate     = ""
  mock_aks_client_key             = ""
  mock_aks_cluster_ca_certificate = ""
}

unit "rg" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/rg"
  path   = "rg"

  values = {
    name = "platform-nc"
  }
}

unit "aca_env" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-env"
  path   = "aca-env"

  values = {
    name                             = "platform-nc"
    log_analytics_retention_in_days = 30
  }

  autoinclude {
    dependency "resource_group" {
      config_path = unit.rg.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        resource_group_name     = local.mock_rg_name
        resource_group_location = local.mock_rg_location
        resource_group_id       = local.mock_rg_id
      }
    }
  }
}

unit "aks" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aks-cluster"
  path   = "aks"

  values = {
    name                      = "platform-nc"
    sku_tier                  = "Free"
    kubernetes_version        = "1.36"
    oidc_issuer_enabled       = true
    workload_identity_enabled = true
    default_node_pool = {
      name                 = "system"
      vm_size              = "Standard_DC2s_v3"
      enable_auto_scaling  = true
      min_count            = 1
      max_count            = 3
      orchestrator_version = "1.36"
    }
  }

  autoinclude {
    dependency "resource_group" {
      config_path = unit.rg.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        resource_group_name     = local.mock_rg_name
        resource_group_location = local.mock_rg_location
        resource_group_id       = local.mock_rg_id
      }
    }
  }
}

unit "argocd" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/argocd"
  path   = "argocd"

  values = {
    argocd_version = "10.3.2"
  }

  autoinclude {
    dependency "aks" {
      config_path = unit.aks.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        host                   = local.mock_aks_host
        client_certificate     = local.mock_aks_client_certificate
        client_key             = local.mock_aks_client_key
        cluster_ca_certificate = local.mock_aks_cluster_ca_certificate
      }
    }
  }
}
