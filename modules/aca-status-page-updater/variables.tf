variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name, for example stg or prod."
  type        = string
}

variable "name" {
  description = "Base name for the workload."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "container_app_environment_name" {
  description = "Container Apps environment name."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace name."
  type        = string
}

variable "log_analytics_retention_in_days" {
  description = "Retention period in days for the Log Analytics workspace."
  type        = number
  default     = 4
}

variable "container_app_name" {
  description = "Azure Container App name."
  type        = string
}

variable "container_name" {
  description = "Container name inside the app."
  type        = string
  default     = "status-page-updater"
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
    secret_name  = string
    secret_value = string
  }))
  default   = {}
  sensitive = true
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
