stack "billing" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/stacks/workers/billing"
  path   = "workers"

  values = {
    # Shared by every worker in this stack.
    container_image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"

    environment_variables = {
      BILLING_CURRENCY = "NZD"
    }

    tags = {
      team = "core"
    }

    # Azure RBAC roles for each worker's managed identity, keyed by a stable name.
    # role_assignments = {
    #   secrets = {
    #     scope = "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<kv>"
    #     role  = "Key Vault Secrets User"
    #   }
    # }

    # Per-worker overrides. Each value replaces the shared one above for that worker.
    workers = {
      "billing-invoices" = {
        max_replicas = 2
      }
      "billing-payments" = {
        container_image = "nginxdemos/hello:latest"
      }
    }
  }
}
