variable "location" {
  description = "Azure region for the storage account."
  type        = string
}

variable "environment" {
  description = "Deployment environment name, for example dev or prod."
  type        = string
}

variable "name" {
  description = "Base name for the workload or shared platform."
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique storage account name."
  type        = string
}

variable "account_tier" {
  description = "Storage account tier."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Storage account replication type."
  type        = string
  default     = "LRS"
}

variable "account_kind" {
  description = "Storage account kind."
  type        = string
  default     = "StorageV2"
}

variable "min_tls_version" {
  description = "Minimum TLS version."
  type        = string
  default     = "TLS1_2"
}

variable "containers" {
  description = "Blob containers to create in the storage account."
  type        = set(string)
  default     = []
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
