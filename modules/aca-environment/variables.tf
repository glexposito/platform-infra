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

variable "log_analytics_enabled" {
  description = "Create a Log Analytics workspace and send the environment's logs to it. When false, logs are only streamed live and not stored."
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace name."
  type        = string
}

variable "log_analytics_retention_in_days" {
  description = "Retention period in days for the Log Analytics workspace."
  type        = number
  default     = 30
}

variable "log_analytics_daily_quota_gb" {
  description = "Daily ingestion cap in GB for the Log Analytics workspace. Resets every day; 0.1 is about 3 GB per month."
  type        = number
  default     = 0.1
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
