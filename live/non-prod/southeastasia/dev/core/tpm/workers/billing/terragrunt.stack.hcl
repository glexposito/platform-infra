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

    # Roles for each worker's managed identity, keyed by a stable name.
    # Required: type, name, role. Optional: resource_group_name (defaults to the
    # workers' resource group), subscription_id (defaults to the deployment's
    # subscription) and child (narrows the grant below the resource).
    # role_assignments = {
    #   secrets = {
    #     type = "key_vault"
    #     name = "kv-billing-dev-sea"
    #     role = "Key Vault Secrets User"
    #   }
    #   jobs = {
    #     type                = "service_bus"
    #     name                = "sb-billing-dev-sea"
    #     resource_group_name = "rg-billing-dev-sea"
    #     child               = "queues/jobs"
    #     role                = "Azure Service Bus Data Sender"
    #   }
    #   billing_db = {
    #     type  = "cosmos"
    #     name  = "cosmos-billing-dev-sea"
    #     child = "dbs/billing"
    #     role  = "Cosmos DB Built-in Data Reader"
    #   }
    # }

    # Per-worker overrides. Each value replaces the shared one above for that worker.
    workers = {
      "billing-invoices" = {
        max_replicas = 2

        # Managed identity smoke test: the queue scaler authenticates with the
        # worker's identity, so 0 -> 1 replicas on a new message proves the
        # identity and its Storage Queue role assignments work.
        min_replicas = 0
        queue_scale = {
          storage_account_name                = "glexpositotfstate01"
          storage_account_resource_group_name = "rg-aca-terraform-state"
          queue_name                          = "billing-invoices"
          queue_length                        = 1
        }
      }
      "billing-payments" = {
        container_image = "nginxdemos/hello:latest"
      }
    }
  }
}
