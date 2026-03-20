variable "environment" {
  description = "Deployment environment name, for example stg or prod."
  type        = string
}

variable "name" {
  description = "Base name for the workload."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where the Container App Environment lives."
  type        = string
}

variable "container_app_environment_id" {
  description = "The ID of the Container App Environment to deploy into."
  type        = string
}

variable "container_app_name" {
  description = "Azure Container App name."
  type        = string
}

variable "container_name" {
  description = "Container name inside the app."
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Full container image reference."
  type        = string
}

variable "container_cpu" {
  description = "CPU allocated to the container."
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "Memory allocated to the container."
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum number of replicas."
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of replicas."
  type        = number
  default     = 1
}

variable "revision_mode" {
  description = "Container App revision mode."
  type        = string
  default     = "Single"
}

variable "environment_variables" {
  description = "Plaintext environment variables for the container."
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Environment variables sourced from Container App secrets."
  type = map(object({
    secret_name         = string
    secret_value        = optional(string)
    key_vault_secret_id = optional(string)
  }))
  default   = {}
  sensitive = true

  validation {
    condition = alltrue([
      for secret in values(var.secret_environment_variables) :
      (
        (try(trimspace(secret.secret_value), "") != "") !=
        (try(trimspace(secret.key_vault_secret_id), "") != "")
      )
    ])
    error_message = "Each secret_environment_variables entry must define exactly one of secret_value or key_vault_secret_id."
  }
}

variable "registry_server" {
  description = "Private registry server, for example myregistry.azurecr.io. Leave null for public images."
  type        = string
  default     = null
}

variable "acr_id" {
  description = "Optional Azure Container Registry resource ID. When set, AcrPull is granted to the app identity."
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
