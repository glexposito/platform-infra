include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/argocd"
}

dependency "aks" {
  config_path = "../aks"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs_merge_strategy_with_state  = "shallow"

  mock_outputs = {
    host                    = "https://mock-aks.example.com"
    client_certificate      = ""
    client_key              = ""
    cluster_ca_certificate  = ""
  }
}

inputs = {
  host                    = dependency.aks.outputs.host
  client_certificate      = dependency.aks.outputs.client_certificate
  client_key              = dependency.aks.outputs.client_key
  cluster_ca_certificate  = dependency.aks.outputs.cluster_ca_certificate
  namespace               = "argocd"
  argocd_version           = "10.3.2"
}
