include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/argocd-bootstrap"
}

dependency "aks" {
  config_path = values.aks_path

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs_merge_strategy_with_state  = "shallow"

  mock_outputs = {
    host                    = "https://mock-aks.example.com"
    client_certificate      = ""
    client_key              = ""
    cluster_ca_certificate  = ""
  }
}

dependency "argocd" {
  config_path = values.argocd_path

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs_merge_strategy_with_state  = "shallow"

  mock_outputs = {
    namespace = "argocd"
  }
}

inputs = {
  host                    = dependency.aks.outputs.host
  client_certificate      = dependency.aks.outputs.client_certificate
  client_key              = dependency.aks.outputs.client_key
  cluster_ca_certificate  = dependency.aks.outputs.cluster_ca_certificate
  namespace               = dependency.argocd.outputs.namespace
  app_name                = try(values.app_name, "platform-apps")
  repo_url                = values.repo_url
  repo_path               = try(values.repo_path, ".")
  repo_revision            = try(values.repo_revision, "main")
}
