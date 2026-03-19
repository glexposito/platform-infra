# aca-infra

Terragrunt/Terraform scaffold for deploying a containerized personal app to Azure Container Apps.

> [!WARNING]
> This repository is a proof of concept.
> It is intended for experimentation and learning in a disposable Azure account, not as a hardened production baseline.
> Expect breaking refactors, manual resets, and destructive rebuilds while the structure is still being explored.

This repository implements a Terragrunt layout inspired by the [Gruntwork Terragrunt Reference Architecture](docs/terragrunt-architecture.md), utilizing a strict hierarchical layout (`subscription/region/environment`) with explicit stack files and shared unit wrappers to maximize configuration reuse and limit blast radius.

## Architecture & Layout

- `modules/aca-environment`: Reusable Terraform module for the shared foundation (Resource Group, Log Analytics, Container App Environment).
- `modules/aca-app`: Reusable Terraform module for deploying specific microservices into an existing `aca-environment`.
- `live/`: The "Live" infrastructure configurations, organized by hierarchy:

```text
live/
├── units/
│   ├── app-env/
│   │   └── terragrunt.hcl
│   └── myapp/
│       └── terragrunt.hcl
├── non-prod/
│   ├── backend.hcl
│   └── australiaeast/
│       ├── region.hcl
│       └── dev/
│           └── terragrunt.stack.hcl
└── prod/
    ├── backend.hcl
    └── australiaeast/
        ├── region.hcl
        └── prod/
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

*Current app token: `myapp`. Current shared environment stack token: `core`. Current region shortcode in use: `aue` for Australia East.*

## Terragrunt Composition

Reusable Terragrunt unit logic lives in:

- `live/units/app-env/terragrunt.hcl`
- `live/units/myapp/terragrunt.hcl`

Each environment now has a small `terragrunt.stack.hcl` file that composes those shared units and passes only per-environment overrides such as the stack name, retention period, image registry settings, or replica counts.

The unit wrappers derive region and environment context from the generated unit location by reading:

- `../../../region.hcl`

The environment name itself is passed explicitly from each `terragrunt.stack.hcl` file, which keeps the layout small and avoids an extra `env.hcl` file per environment.

## Required Environment Variables

To run Terragrunt locally, you need the following Azure authentication variables:

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

Terraform backend coordinates are versioned in the Terragrunt configuration under `live/*/backend.hcl`.

## Workload-Specific Environment Variables

- `STATUSPAGE_API_KEY`

The image reference and optional registry settings are versioned in each environment `terragrunt.stack.hcl`.

## Example Usage

For full environment deployment, run from the environment root so Terragrunt can generate and apply `app-env` before `myapp`:

```bash
cd live/non-prod/australiaeast/dev
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

## GitHub Actions CI/CD

The workflow is located in [`.github/workflows/provision-myapp-infra.yml`](.github/workflows/provision-myapp-infra.yml).

- **Pull Requests**: Automatically runs `terragrunt run --all plan` from each environment root.
- **Manual Dispatch**: Allows applying changes to specific environments such as `dev` or `prod-aue`.

### Required GitHub Secrets

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

> 💡 **Security Recommendation:** Currently, application secrets like `STATUSPAGE_API_KEY` are passed via GitHub Secrets. For enterprise production workloads, it is highly recommended to migrate these to **Azure Key Vault**. You can grant the Container App's Managed Identity `Key Vault Secrets User` access and reference the secret natively, keeping plain-text values entirely out of GitHub Actions and Terraform state files.

### Optional GitHub Variables

- `TERRAFORM_VERSION`
- `TERRAGRUNT_VERSION`

### Recommended GitHub Setup

1. Create GitHub Environments named `dev` and `prod-aue`.
2. Add approval rules for the production environment.
3. Configure Azure federated credentials to trust the repo and those specific environments.
4. Set the workload-specific secrets (`STATUSPAGE_API_KEY`) on the environments that need them. The PR `plan` job only sees repository-level `vars` and `secrets`, so keep shared version pins there unless the workflow is changed to attach GitHub environments during PR plans.

If `STATUSPAGE_API_KEY` is unset, the app config omits that secret entirely rather than sending an empty secret to Azure Container Apps.
