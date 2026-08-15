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
  description = "Namespace the Gateway is created in. Must be where Envoy Gateway itself was installed."
  type        = string
}

variable "gateway_class_name" {
  description = "Name of the GatewayClass, pointing at the Envoy Gateway controller."
  type        = string
  default     = "eg"
}

variable "gateway_name" {
  description = "Name of the Gateway."
  type        = string
  default     = "eg"
}

variable "listener_port" {
  description = "Port the Gateway's HTTP listener accepts traffic on."
  type        = number
  default     = 80
}
