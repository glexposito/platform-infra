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
    resource_group_path             = "../rg"
    name                            = "platform-nc"
    log_analytics_retention_in_days = 30
  }
}

unit "aks" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aks-cluster"
  path   = "aks"

  values = {
    resource_group_path = "../rg"
    name                 = "platform-nc"
    sku_tier             = "Free"
    kubernetes_version   = "1.36"
    default_node_pool = {
      name                  = "system"
      vm_size               = "Standard_B2s"
      node_count            = 1
      orchestrator_version  = "1.36"
    }
  }
}

unit "envoy-gateway" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/envoy-gateway"
  path   = "envoy-gateway"

  values = {
    aks_path = "../aks"
  }
}

unit "envoy-gateway-config" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/envoy-gateway-config"
  path   = "envoy-gateway-config"

  values = {
    aks_path           = "../aks"
    envoy_gateway_path = "../envoy-gateway"
  }
}

unit "argocd" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/argocd"
  path   = "argocd"

  values = {
    aks_path       = "../aks"
    argocd_version = "10.3.2"
  }
}

unit "argocd-bootstrap" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/argocd-bootstrap"
  path   = "argocd-bootstrap"

  values = {
    aks_path    = "../aks"
    argocd_path = "../argocd"
    # Terraform's job stops here -- once this Application exists, Argo CD
    # owns everything under repo_path in that repo from here on.
    repo_url  = "https://github.com/glexposito/k8s-playground.git"
    repo_path = "argocd"
  }
}
