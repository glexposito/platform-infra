# aca-infra

Terragrunt/Terraform scaffold for deploying a containerized personal app to Azure Container Apps.

This repository implements the [Gruntwork Terragrunt Reference Architecture](docs/terragrunt-architecture.md), utilizing a strict hierarchical layout (`subscription/region/environment/service`) to maximize configuration reuse (DRY) and strictly limit the blast radius of changes.

## Architecture & Layout

- `modules/aca-environment`: Reusable Terraform module for the shared foundation (Resource Group, Log Analytics, Container App Environment).
- `modules/aca-app`: Reusable Terraform module for deploying specific microservices into an existing `aca-environment`.
- `live/`: The "Live" infrastructure configurations, organized by hierarchy:

```text
live/
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
- 📖 [**Terragrunt Architecture Guide**](docs/terragrunt-architecture.md): How to add new regions, manage inheritance, and safely decommission environments.
- 📖 [**Configuration Variables Guide**](docs/configuration-variables.md): Explanation of resource tagging vs. physical naming conventions.
- 📖 [**GitHub Actions & Azure Setup**](docs/azure-github-actions-setup.md): Guide for bootstrapping the Azure OIDC connection and State storage.

---

## Naming Convention

Azure naming conventions are generated dynamically based on the inherited folder structure:

- Resource Group: `rg-<service>-<env>-<region>`
- Container Apps Environment: `cae-<service>-<env>-<region>`
- Log Analytics Workspace: `law-<service>-<env>-<region>`
- Container App: `ca-<service>-<env>-<region>`

*Current service token (`myapp`) and regions (`aue` for Australia East, `sea` for Southeast Asia).*

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

Navigate to the specific leaf directory of the environment/region you wish to deploy:

```bash
cd live/non-prod/australiaeast/dev/myapp
terragrunt init
terragrunt plan
terragrunt apply
```

## GitHub Actions CI/CD

The workflow is located in [`.github/workflows/provision-myapp-infra.yml`](.github/workflows/provision-myapp-infra.yml).

- **Pull Requests**: Automatically runs `terragrunt plan` against all defined environments.
- **Manual Dispatch**: Allows applying changes to specific environments. Supports comma-separated targets such as `dev,stg`. Applying to multiple `prod-*` targets simultaneously is intentionally restricted to prevent cascading failures.

### Required GitHub Secrets

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `STATUSPAGE_API_KEY`

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
4. Set the workload-specific variables (`STATUSPAGE_API_KEY`, image tags) as Environment Secrets/Variables.
