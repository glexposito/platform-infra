# platform-infra

Lean Terragrunt proof of concept for Azure platform and app infrastructure on Azure Container Apps.

> [!WARNING]
> This repository is a proof of concept for a disposable Azure account.
> Expect refactors, rebuilds, and manual cleanup while the layout is still evolving.

## What It Does

- `platform/` manages shared Azure resources, split into three independently-deployed stacks:
  - `platform/rg` — resource group
  - `platform/compute` — Log Analytics workspace, Container Apps environment, AKS cluster
  - `platform/workloads` — ArgoCD (installed onto the AKS cluster)
- app stack folders (e.g. `pulse-api/`) manage one Container App per stack.

```text
live/
├── non-prod/
│   └── southeastasia/
│       └── dev/
│           ├── platform/
│           │   ├── rg/
│           │   ├── compute/
│           │   └── workloads/
│           ├── pulse-api/
│           └── <app-stack>/
units/
├── rg/
├── aca-env/
├── aca-app/
├── aci-app/
├── aks-cluster/
├── argocd/
└── storage-account/
```

Reusable Terraform modules live in `modules/`. Reusable Terragrunt wrappers live in `units/`.

## Naming

Every resource name is built from the same four pieces: `<resource-prefix>-<name>-<environment>-<location>`.

| Piece | Where it comes from | Example |
|---|---|---|
| `<resource-prefix>` | Fixed per resource type (see table below) | `rg`, `aks`, `cae` |
| `<name>` | `values.name` in the owning `terragrunt.stack.hcl` unit block | `platform`, `pulse-api` |
| `<environment>` | `env.hcl` (`environment = "dev"`) | `dev` |
| `<location>` | `region.hcl` (`location_short = "sea"`) | `sea` |

| Resource | Prefix | Example |
|---|---|---|
| Resource group | `rg` | `rg-platform-dev-sea` |
| AKS cluster | `aks` | `aks-platform-dev-sea` |
| Container Apps environment | `cae` | `cae-platform-dev-sea` |
| Log Analytics workspace | `law` | `law-platform-dev-sea` |
| Storage account | `st` | `stplatformdevsea` (no hyphens — storage account names must be lowercase alphanumeric only) |
| Container App | `ca` | `ca-pulse-api-dev-sea` |
| User-assigned managed identity | `id` | `id-pulse-api-dev-sea` |

Current shared stack token: `platform`
Current region short code: `sea`

Terraform state keys follow the same `<environment>/<location>/<name>` pieces plus the leaf unit directory name, but `<name>` there comes from a separately-declared `stack.hcl` file rather than `values.name` directly — see [Naming: state key vs resource naming](docs/terragrunt-architecture.md#naming-state-key-vs-resource-naming) for why, and keep the two in sync by hand when renaming a stack.

### Worked example: multiple environment tiers

Only `live/non-prod/southeastasia/dev` exists today, but `values.name` and `environment` are independent knobs by design — worth knowing before adding a `prod` tier later, so names stay predictable:

| Environment tier | `values.name` | Resulting AKS name |
|---|---|---|
| `dev` (internal use) | `platform-internal` | `aks-platform-internal-dev-sea` |
| `prod` | `platform` | `aks-platform-prod-sea` |

`prod` would keep `values.name = "platform"` rather than `"platform-prod"` — `environment` already contributes `prod` to the name, so repeating it in `name` would produce `aks-platform-prod-prod-sea`. Only add a qualifier to `name` when it distinguishes something `environment` doesn't already cover (here, `-internal` marks that `dev` is used for internal purposes, not just early-stage testing).

### Directory and unit naming

- Environment tiers: `live/<non-prod|prod>/<region>/<environment>/` — e.g. `live/non-prod/southeastasia/dev/`.
- Stack folders: one per logical component group, e.g. `platform/` (shared cluster/platform resources, itself split into `rg`/`compute`/`workloads`), `pulse-api/` (one app).
- Unit block labels inside a `terragrunt.stack.hcl` usually match their `path` value, e.g. `unit "rg" { path = "rg" }` and `unit "argocd" { path = "argocd" }`. This is convention, not a hard rule — app stacks are the exception: [`pulse-api/terragrunt.stack.hcl`](live/non-prod/southeastasia/dev/pulse-api/terragrunt.stack.hcl) labels its unit `"pulse-api"` but fixes `path = "app"`, so every app stack's working directory is `<app-stack>/app/` regardless of the app's own name.

## Local Usage

Authenticate first:

```bash
az login
az account set --subscription "<subscription-id>"
```

Deploy the platform stack (runs `rg`, `compute`, and `workloads` together — Terragrunt resolves the dependency order via each unit's `autoinclude` block):

```bash
cd live/non-prod/southeastasia/dev/platform
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

Deploy an app stack:

```bash
cd live/non-prod/southeastasia/dev/<app-stack>
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

Workload settings such as `container_image`, scale settings, ingress, probes, environment variables, and secrets live in each stack `terragrunt.stack.hcl`.

An app can scale from an Azure Storage Queue without storing an account key. Every Container App gets its own user-assigned managed identity (see [Managed identity and access](#managed-identity-and-access)); setting `queue_scale` configures an Azure Queue scale rule that uses that identity and grants it the `Storage Queue Data Reader` and `Storage Queue Data Message Processor` roles on the storage account:

```hcl
queue_scale = {
  storage_account_name = "stpulsedevsea"
  queue_name           = "pulse-work"
  queue_length         = 5
}
```

The storage account is expected in the app's resource group. Add `storage_account_resource_group_name` when it lives elsewhere. `queue_length` is the target number of messages per replica. The rule can scale the app to the configured `max_replicas`; set `min_replicas = 0` to scale to zero when the queue is empty. Keep a replica running or configure an HTTP scale rule if the same app must also wake for public HTTP traffic.

For an Azure Service Bus Queue, use the separate `service_bus_queue_scale` setting. The module configures the `azure-servicebus` rule, and grants the app identity `Azure Service Bus Data Receiver` on that queue:

```hcl
service_bus_queue_scale = {
  namespace_name = "sb-pulsedevsea"
  queue_name     = "pulse-work"
  message_count  = 5
}
```

The Service Bus namespace is expected in the app's resource group. Add `namespace_resource_group_name` when it lives elsewhere.

### Managed identity and access

Each Container App gets its own user-assigned managed identity (`id-<name>-<environment>-<location>`), created by [`modules/managed-identity`](modules/managed-identity). `aca-app` calls that module internally, and future app modules (App Service, Functions, ...) should do the same, so the identity and grant logic lives in one place. The identity, and every role assignment, is created before the app, so the first revision starts with its access already in place. `AZURE_CLIENT_ID` is set on the container so `DefaultAzureCredential` picks the identity.

Grant access from the stack values with one `role_assignments` map. Point at resources by name; `resource_group_name` defaults to the app's resource group and `subscription_id` to the provider's subscription, so set them only for resources that live elsewhere:

```hcl
role_assignments = {
  secrets = {
    type = "key_vault"            # acr, cosmos, key_vault, managed_redis, service_bus, storage_account, or e.g. "Microsoft.Sql/servers"
    name = "kv-billing-dev-sea"
    role = "Key Vault Secrets User"
  }
  jobs = {
    type                = "service_bus"
    name                = "sb-billing-dev-sea"
    resource_group_name = "rg-billing-dev-sea"
    subscription_id     = "<sub-id>"      # optional, only for resources in another subscription
    child               = "queues/jobs"   # optional, narrows the grant below the resource
    role                = "Azure Service Bus Data Sender"
  }
  orders = {
    type  = "cosmos"
    name  = "cosmos-orders-dev-sea"
    child = "dbs/orders"                      # optional; "dbs/orders/colls/<container>" narrows further
    role  = "Cosmos DB Built-in Data Reader"
  }
  cache = {
    type = "managed_redis"
    name = "amr-orders-dev-sea"
    role = "Managed Redis Data Access"         # full data access via the cache's default access policy
  }
}
```

Most services use Azure RBAC. Cosmos DB (NoSQL) data access uses its own role system instead: `Cosmos DB Built-in Data Reader`, `Cosmos DB Built-in Data Contributor`, or a custom `sqlRoleDefinitions` ID is granted as a Cosmos data-plane role assignment, while any other role on a Cosmos account (for example `Cosmos DB Account Reader Role`) is a normal Azure RBAC assignment.

Azure Managed Redis works the same way: `Managed Redis Data Access` becomes an access policy assignment on the cache, which grants the default (full) access policy, and any other role on the cache is a normal Azure RBAC assignment. Clients connect with the identity's principal (object) ID as the Redis user name and an Entra token as the password. The classic Azure Cache for Redis tiers are not supported because they are being retired.

When the target is created by another unit in this repo, pass its ID from a Terragrunt `dependency` instead of `type` and `name`, for example `scope = dependency.kv.outputs.key_vault_id`. Resources in another subscription must be in the same Entra tenant, and the deploying principal needs permission to create role assignments there.

Azure SQL access is not covered: database users for an Entra identity are created with T-SQL (`CREATE USER [...] FROM EXTERNAL PROVIDER`), not with Azure RBAC.

Secrets can use a direct value or a Key Vault reference:

```hcl
secret_environment_variables = {
  EXAMPLE_DIRECT = {
    secret_name  = "example-direct"
    secret_value = trimspace(get_env("EXAMPLE_DIRECT", ""))
  }

  EXAMPLE_KEY_VAULT = {
    secret_name         = "example-key-vault"
    key_vault_secret_id = "https://<vault>.vault.azure.net/secrets/<secret>"
  }
}
```

`key_vault_secret_id` is the secret's URI (optionally with a version), not its ARM resource ID. The app's identity reads it, so also grant `Key Vault Secrets User` on the vault through `role_assignments`.

## GitHub Actions

- [`.github/workflows/provision-platform.yml`](.github/workflows/provision-platform.yml) runs Terragrunt for `platform` (`rg`, `compute`, `workloads`)
- [`.github/workflows/deploy-app.yml`](.github/workflows/deploy-app.yml) runs Terragrunt for one app stack

Terragrunt workflows recalculate at `apply` time instead of reusing saved plan files.

Required GitHub configuration:

- Secret: `AZURE_CLIENT_ID`
- Variables: `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

Recommended setup:

1. Create a GitHub Environment named `dev`.
2. Configure Azure federated credentials for that GitHub Environment.

## Docs

- [Testing Terragrunt in Azure](docs/testing-terragrunt.md)
- [Terragrunt Layout](docs/terragrunt-architecture.md)
- [Azure and GitHub Actions](docs/azure-github-actions-setup.md)
