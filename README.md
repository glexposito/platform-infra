# platform-infra

Terragrunt proof of concept for Azure platform infrastructure, shared services, and environment provisioning.

> [!WARNING]
> This repository is a proof of concept.
> It is intended for experimentation and learning in a disposable Azure account, not as a hardened production baseline.
> Expect breaking refactors, manual resets, and destructive rebuilds while the structure is still being explored.

This repository implements a Terragrunt layout inspired by the [Gruntwork Terragrunt Reference Architecture](docs/terragrunt-architecture.md), utilizing a strict hierarchical layout (`environment-group/backend -> region -> environment`) with explicit stack files and shared unit wrappers to maximize configuration reuse and limit blast radius.

## Architecture & Layout

- `modules/aca-environment`: Reusable Terraform module for the shared foundation (Resource Group, Log Analytics, Container App Environment).
- `modules/aca-app`: Reusable Terraform module for deploying specific microservices into an existing `aca-environment`.
- `live/`: The "Live" infrastructure configurations, organized by hierarchy:

```text
live/
├── units/
│   ├── aca-env/
│   │   └── terragrunt.hcl
│   ├── rg/
│   │   └── terragrunt.hcl
│   ├── storage-account/
│   │   └── terragrunt.hcl
│   └── aca-app/
│       └── terragrunt.hcl
├── non-prod/
│   ├── backend.hcl
│   └── westeurope/
│       ├── region.hcl
│       └── dev/
│           ├── platform-noncritical/
│           │   └── terragrunt.stack.hcl
│           ├── myapp-1/
│           │   └── terragrunt.stack.hcl
│           └── myapp-3/
│               └── terragrunt.stack.hcl
└── prod/
    ├── backend.hcl
    └── westeurope/
        ├── region.hcl
        └── prod/
            ├── platform-noncritical/
            │   └── terragrunt.stack.hcl
            └── myapp-1/
                └── terragrunt.stack.hcl
```

### Documentation
For detailed information on how to work with this architecture, see the following guides:
- 📖 [**Terraform & Terragrunt Concepts**](docs/terraform-terragrunt-concepts.md): Foundations of IaC and how they are implemented in this repository.
- 📖 [**Terragrunt Architecture Guide**](docs/terragrunt-architecture.md): How to add new regions, manage inheritance, and safely decommission environments.
- 📖 [**GitHub Actions & Azure Setup**](docs/azure-github-actions-setup.md): Guide for bootstrapping the Azure OIDC connection and State storage.

---

## Naming Convention

Azure naming conventions are generated dynamically from the shared stack token, app token, environment, and region shortcode:

- Shared environment resource group: `rg-<shared-stack>-<env>-<region>`
- Shared Container Apps environment: `cae-<shared-stack>-<env>-<region>`
- Shared Log Analytics workspace: `law-<shared-stack>-<env>-<region>`
- Application Container App: `ca-<app>-<env>-<region>`

*Current app tokens in live config: `myapp-1` and `myapp-3` in `dev`, `myapp-1` in `prod`. Current shared environment stack token: `platform-noncritical`. Current region shortcode in use: `weu` for West Europe.*

## Terragrunt Composition

Reusable Terragrunt unit logic lives in:

- `live/units/rg/terragrunt.hcl`
- `live/units/storage-account/terragrunt.hcl`
- `live/units/aca-env/terragrunt.hcl`
- `live/units/aca-app/terragrunt.hcl`

Each environment now has one stack folder per deployable unit, such as `platform-noncritical/` for the shared foundation and one folder per app. The platform stack composes the shared foundation units, while each app stack targets a single app deployment against an existing Container Apps environment.

The unit wrappers derive region and environment context from the generated unit location by reading:

- `../../../../region.hcl`

The environment name itself is passed explicitly from each `terragrunt.stack.hcl` file, which keeps the layout small and avoids an extra `env.hcl` file per environment.

## Required Environment Variables

Terraform backend coordinates are versioned in the Terragrunt configuration under `live/*/backend.hcl`.

For local Terragrunt usage, authenticate with Azure CLI:

```bash
az login
az account set --subscription "<subscription-id>"
```

## Workload-Specific Settings

The image reference, optional registry settings, environment variables, and secret environment variables are versioned in each environment `terragrunt.stack.hcl`.

`secret_environment_variables` supports either a direct secret value or an Azure Key Vault reference per secret. Each entry must set exactly one of:

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

## Example Usage

For aggregate platform deployment, run from the platform root:

```bash
cd live/non-prod/westeurope/dev/platform-noncritical
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

For a single app deployment, run from that app root:

```bash
cd live/non-prod/westeurope/dev/myapp-1
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

## GitHub Actions CI/CD

The workflows are located in:

- [`.github/workflows/provision-platform.yml`](.github/workflows/provision-platform.yml)
- [`.github/workflows/deploy-app.yml`](.github/workflows/deploy-app.yml)

- **Platform workflow**: runs `plan` or `apply` against the platform stack for `dev` or `prod-weu`
- **App workflow**: runs `plan` or `apply` for a single app/environment pair

### Required GitHub Secrets

- `AZURE_CLIENT_ID`

> 💡 **Security Recommendation:** Application secrets passed through `secret_environment_variables` should ideally come from Azure Key Vault or another managed secret store instead of being stored directly in CI or Terraform state.

### Optional GitHub Variables

- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

These can be defined at repository level or at GitHub Environment level for `dev` and `prod-weu`.

Terraform and Terragrunt versions are pinned directly in the workflow file.

### Recommended GitHub Setup

1. Create GitHub Environments named `dev` and `prod-weu`.
2. Add approval rules for the production environment.
3. Configure Azure federated credentials to trust the repo and those specific environments.
4. Set the workload-specific variables and secrets required by each app unit.
