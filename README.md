# aca-infra

Terragrunt/Terraform scaffold for deploying a containerized personal app to Azure Container Apps.

> [!WARNING]
> This repository is a proof of concept.
> It is intended for experimentation and learning in a disposable Azure account, not as a hardened production baseline.
> Expect breaking refactors, manual resets, and destructive rebuilds while the structure is still being explored.

This repository implements the [Gruntwork Terragrunt Reference Architecture](docs/terragrunt-architecture.md), utilizing a strict hierarchical layout (`subscription/region/environment/service`) to maximize configuration reuse (DRY) and strictly limit the blast radius of changes.

## Architecture & Layout

- `modules/aca-environment`: Reusable Terraform module for the shared foundation (Resource Group, Log Analytics, Container App Environment).
- `modules/aca-app`: Reusable Terraform module for deploying specific microservices into an existing `aca-environment`.
- `live/`: The "Live" infrastructure configurations, organized by hierarchy:

```text
live/
├── _shared/
│   ├── app-env.hcl
│   ├── app.hcl
│   └── myapp.hcl
├── non-prod/
│   └── australiaeast/
│       ├── dev/
│       └── stg/
└── prod/
    ├── australiaeast/
    │   └── prod/
    └── southeastasia/
        └── prod/
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

*Current app token: `myapp`. Current shared environment stack token: `core`. Current region shortcodes: `aue` for Australia East and `sea` for Southeast Asia.*

## Shared Terragrunt Config

Common stack logic lives in:

- `live/_shared/app-env.hcl`
- `live/_shared/app.hcl`
- `live/_shared/myapp.hcl`

Each environment-specific leaf file stays small and includes the shared config. The shared files still resolve the correct region and environment by using `get_original_terragrunt_dir()`, which points to the actual leaf stack directory Terragrunt was invoked for. From that real directory:

- `../../region.hcl` resolves the region config
- `../env.hcl` resolves the environment config

So when Terragrunt runs from `live/non-prod/australiaeast/dev/myapp`, the shared config reads:

- `live/non-prod/australiaeast/region.hcl`
- `live/non-prod/australiaeast/dev/env.hcl`

This keeps the repo DRY without losing per-environment behavior.

## Required Environment Variables

To run Terragrunt locally, you need the following Azure authentication and state variables:

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `TG_STATE_RESOURCE_GROUP`
- `TG_STATE_STORAGE_ACCOUNT`
- `TG_STATE_CONTAINER`

## Workload-Specific Environment Variables

- `MYAPP_IMAGE`
- `MYAPP_REGISTRY_SERVER` (optional)
- `MYAPP_ACR_ID` (optional)
- `STATUSPAGE_API_KEY`

## Example Usage

For full environment deployment, run from the environment root so Terragrunt can apply `app-env` before `myapp`:

```bash
cd live/non-prod/australiaeast/dev
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

## GitHub Actions CI/CD

The workflow is located in [`.github/workflows/provision-myapp-infra.yml`](.github/workflows/provision-myapp-infra.yml).

- **Pull Requests**: Automatically runs `terragrunt run --all plan` from each environment root.
- **Manual Dispatch**: Allows applying changes to specific environments. Supports comma-separated targets such as `dev,stg`. Applying to multiple `prod-*` targets simultaneously is intentionally restricted to prevent cascading failures.

### Required GitHub Secrets

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

> 💡 **Security Recommendation:** Currently, application secrets like `STATUSPAGE_API_KEY` are passed via GitHub Secrets. For enterprise production workloads, it is highly recommended to migrate these to **Azure Key Vault**. You can grant the Container App's Managed Identity `Key Vault Secrets User` access and reference the secret natively, keeping plain-text values entirely out of GitHub Actions and Terraform state files.

### Required GitHub Variables (Repository or Environment level)

- `TG_STATE_RESOURCE_GROUP`
- `TG_STATE_STORAGE_ACCOUNT`
- `TG_STATE_CONTAINER`

### Optional GitHub Variables

- `TERRAFORM_VERSION`
- `TERRAGRUNT_VERSION`
- `MYAPP_IMAGE`
- `MYAPP_REGISTRY_SERVER`
- `MYAPP_ACR_ID`

### Recommended GitHub Setup

1. Create GitHub Environments named `dev`, `stg`, `prod-aue`, and `prod-sea`.
2. Add approval rules for the `prod-*` environments.
3. Configure Azure federated credentials to trust the repo and those specific environments.
4. Set the workload-specific variables and secrets (`STATUSPAGE_API_KEY`, image tags) on the environments that need them. The PR `plan` job only sees repository-level `vars` and `secrets`, so keep values there unless the workflow is changed to attach GitHub environments during PR plans.

If `STATUSPAGE_API_KEY` is unset, the app config omits that secret entirely rather than sending an empty secret to Azure Container Apps.
