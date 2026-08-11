include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/envoy-gateway-config"
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

dependency "envoy_gateway" {
  config_path = values.envoy_gateway_path

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs_merge_strategy_with_state  = "shallow"

  mock_outputs = {
    namespace = "envoy-gateway-system"
  }
}

inputs = {
  host                    = dependency.aks.outputs.host
  client_certificate      = dependency.aks.outputs.client_certificate
  client_key              = dependency.aks.outputs.client_key
  cluster_ca_certificate  = dependency.aks.outputs.cluster_ca_certificate
  namespace               = dependency.envoy_gateway.outputs.namespace
  gateway_class_name      = try(values.gateway_class_name, "eg")
  gateway_name            = try(values.gateway_name, "eg")
  listener_port           = try(values.listener_port, 80)
}
