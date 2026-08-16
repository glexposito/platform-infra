locals {
  mock_aks_host                   = "https://mock-aks.example.com"
  mock_aks_client_certificate     = ""
  mock_aks_client_key             = ""
  mock_aks_cluster_ca_certificate = ""
}

unit "argocd" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/argocd"
  path   = "argocd"

  values = {
    name           = "platform"
    argocd_version = "10.3.2"
  }

  autoinclude {
    dependency "aks" {
      config_path = "${get_repo_root()}/live/non-prod/southeastasia/dev/platform/compute/.terragrunt-stack/aks"

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
