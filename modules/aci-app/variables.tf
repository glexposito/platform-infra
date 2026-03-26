variable "environment" {
  description = "Deployment environment name, for example stg or prod."
  type        = string
}

variable "name" {
  description = "Base name for the workload."
  type        = string
}

variable "location" {
  description = "Azure region for the container group."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where the container group is deployed."
  type        = string
}

variable "container_group_name" {
  description = "Azure Container Instance container group name."
  type        = string
}

variable "os_type" {
  description = "Operating system for the container group."
  type        = string
  default     = "Linux"
}

variable "restart_policy" {
  description = "Restart policy for the container group."
  type        = string
  default     = "Always"
}

variable "ip_address_type" {
  description = "IP address type for the container group."
  type        = string
  default     = "None"
}

variable "dns_name_label" {
  description = "Optional DNS label for public container groups."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Optional subnet IDs for private network integration."
  type        = list(string)
  default     = null
}

variable "containers" {
  description = "Container definitions for the container group."
  type = list(object({
    name   = string
    image  = string
    cpu    = number
    memory = number
    ports = optional(list(object({
      port     = number
      protocol = optional(string, "TCP")
    })), [])
    environment_variables        = optional(map(string), {})
    secure_environment_variables = optional(map(string), {})
    commands                     = optional(list(string), [])
    readiness_probe = optional(object({
      exec                  = optional(list(string))
      initial_delay_seconds = optional(number)
      period_seconds        = optional(number)
      failure_threshold     = optional(number)
      success_threshold     = optional(number)
      timeout_seconds       = optional(number)
      http_get = optional(object({
        path         = optional(string)
        port         = optional(number)
        scheme       = optional(string)
        http_headers = optional(map(string), {})
      }))
    }))
    liveness_probe = optional(object({
      exec                  = optional(list(string))
      initial_delay_seconds = optional(number)
      period_seconds        = optional(number)
      failure_threshold     = optional(number)
      success_threshold     = optional(number)
      timeout_seconds       = optional(number)
      http_get = optional(object({
        path         = optional(string)
        port         = optional(number)
        scheme       = optional(string)
        http_headers = optional(map(string), {})
      }))
    }))
  }))

  validation {
    condition     = length(var.containers) > 0
    error_message = "Define at least one container in containers."
  }
}

variable "image_registry_credential" {
  description = "Optional private registry credentials."
  type = object({
    server   = string
    username = string
    password = string
  })
  default   = null
  sensitive = true
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
