variable "host" {
  description = "Kubernetes API server endpoint of the target cluster."
  type        = string
}

variable "client_certificate" {
  description = "Client certificate (PEM) for authenticating to the cluster."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Client key (PEM) for authenticating to the cluster."
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM)."
  type        = string
  sensitive   = true
}

variable "namespace" {
  description = "Namespace to install Envoy Gateway into."
  type        = string
  default     = "envoy-gateway-system"
}

variable "envoy_gateway_version" {
  description = "Envoy Gateway Helm chart version. Check https://github.com/envoyproxy/gateway/releases before changing the default."
  type        = string
  default     = "v1.8.3"
}
