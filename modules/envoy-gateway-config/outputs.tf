output "gateway_class_name" {
  description = "GatewayClass name, for HTTPRoutes to reference."
  value       = var.gateway_class_name
}

output "gateway_name" {
  description = "Gateway name, for HTTPRoutes to reference."
  value       = var.gateway_name
}

output "gateway_namespace" {
  description = "Namespace the Gateway was created in."
  value       = var.namespace
}
