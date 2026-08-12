include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/argocd-bootstrap"
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
