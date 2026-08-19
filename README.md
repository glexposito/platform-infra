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

Secrets can use a direct value or a Key Vault reference:

```hcl
secret_environment_variables = {
  EXAMPLE_DIRECT = {
    secret_name  = "example-direct"
    secret_value = trimspace(get_env("EXAMPLE_DIRECT", ""))
  }

  EXAMPLE_KEY_VAULT = {
    secret_name         = "example-key-vault"
    key_vault_secret_id = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault>/secrets/<secret>"
  }
}
```

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

- [Terraform and Terragrunt](docs/terraform-terragrunt-concepts.md)
- [Terragrunt Layout](docs/terragrunt-architecture.md)
- [Azure and GitHub Actions](docs/azure-github-actions-setup.md)
