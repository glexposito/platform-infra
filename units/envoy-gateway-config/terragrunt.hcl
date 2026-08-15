include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/envoy-gateway-config"
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
