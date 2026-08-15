locals {
  mock_rg_name     = "mock-rg"
  mock_rg_location = "southeastasia"

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
      }
    }
  }
}

unit "aks" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aks-cluster"
  path   = "aks"

  values = {
    name               = "platform-nc"
    sku_tier           = "Free"
    kubernetes_version = "1.36"
    default_node_pool = {
      name                 = "system"
      vm_size              = "Standard_D2pls_v5"
      node_count           = 1
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

unit "argocd_bootstrap" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/argocd-bootstrap"
  path   = "argocd-bootstrap"

  values = {
    # Terraform's job stops here -- once this Application exists, Argo CD
    # owns everything under repo_path in that repo from here on.
    repo_url  = "https://github.com/glexposito/k8s-playground.git"
    repo_path = "argocd"
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

    dependency "argocd" {
      config_path = unit.argocd.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        namespace = "argocd"
      }
    }
  }
}
