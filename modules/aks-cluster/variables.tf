variable "location" {
  description = "Azure region for the cluster."
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

variable "resource_group_name" {
  description = "Resource group name where the cluster is deployed."
  type        = string
}

variable "cluster_name" {
  description = "Azure Kubernetes Service cluster name."
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster. Defaults to cluster_name when not set."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version. Leave null to use the current AKS default."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS control plane SKU tier."
  type        = string
  default     = "Free"
}

variable "default_node_pool" {
  description = "System node pool configuration."
  type = object({
    name                 = optional(string, "system")
    vm_size              = optional(string, "Standard_B2s")
    node_count           = optional(number, 1)
    min_count            = optional(number)
    max_count            = optional(number)
    enable_auto_scaling  = optional(bool, false)
    os_disk_size_gb      = optional(number, 30)
    orchestrator_version = optional(string) # node pool's Kubernetes version; independent of kubernetes_version, must be bumped separately
    upgrade_max_surge    = optional(string, "1")
  })
  default = {}
}

variable "automatic_upgrade_channel" {
  description = "Control plane auto-upgrade channel. One of patch, rapid, node-image, stable. Leave null to manage kubernetes_version manually."
  type        = string
  default     = null
}

variable "node_os_upgrade_channel" {
  description = "Node OS image auto-upgrade channel. One of Unmanaged, SecurityPatch, NodeImage, None."
  type        = string
  default     = null
}

variable "network_plugin" {
  description = "Network plugin used for pod networking."
  type        = string
  default     = "azure"
}

variable "oidc_issuer_enabled" {
  description = "Enable the OIDC issuer, required for workload identity federation."
  type        = bool
  default     = false
}

variable "workload_identity_enabled" {
  description = "Enable Azure AD workload identity."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
