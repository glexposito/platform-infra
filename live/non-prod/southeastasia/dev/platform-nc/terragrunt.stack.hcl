unit "rg" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/rg"
  path   = "rg"

  values = {
    name = "platform-nc"
  }
}

unit "aca-env" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-env"
  path   = "aca-env"

  values = {
    name                             = "platform-nc"
    log_analytics_retention_in_days = 30
  }

  autoinclude {
    dependency "resource_group" {
      config_path = unit.rg.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        resource_group_name     = "mock-rg"
        resource_group_location = "southeastasia"
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
      vm_size              = "Standard_DC2s_v3"
      node_count           = 1
      orchestrator_version = "1.36"
    }
  }

  autoinclude {
    dependency "resource_group" {
      config_path = unit.rg.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        resource_group_name     = "mock-rg"
        resource_group_location = "southeastasia"
      }
    }
  }
}

unit "envoy-gateway" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/envoy-gateway"
  path   = "envoy-gateway"

  autoinclude {
    dependency "aks" {
      config_path = unit.aks.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        host                   = "https://mock-aks.example.com"
        client_certificate     = ""
        client_key             = ""
        cluster_ca_certificate = ""
      }
    }
  }
}

unit "envoy-gateway-config" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/envoy-gateway-config"
  path   = "envoy-gateway-config"

  autoinclude {
    dependency "aks" {
      config_path = unit.aks.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        host                   = "https://mock-aks.example.com"
        client_certificate     = ""
        client_key             = ""
        cluster_ca_certificate = ""
      }
    }

    dependency "envoy_gateway" {
      config_path = unit["envoy-gateway"].path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        namespace = "envoy-gateway-system"
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

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        host                   = "https://mock-aks.example.com"
        client_certificate     = ""
        client_key             = ""
        cluster_ca_certificate = ""
      }
    }
  }
}

unit "argocd-bootstrap" {
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

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        host                   = "https://mock-aks.example.com"
        client_certificate     = ""
        client_key             = ""
        cluster_ca_certificate = ""
      }
    }

    dependency "argocd" {
      config_path = unit.argocd.path

      mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
      mock_outputs_merge_strategy_with_state  = "shallow"

      mock_outputs = {
        namespace = "argocd"
      }
    }
  }
}
