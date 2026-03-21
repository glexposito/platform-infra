# platform-infra

Terragrunt proof of concept for Azure platform and app infrastructure on Azure Container Apps.

> [!WARNING]
> This repository is a proof of concept for a disposable Azure account.
> Expect refactors, rebuilds, and manual cleanup while the layout is still evolving.

## Layout

This repo keeps shared platform resources separate from app-specific resources:

- `platform-noncritical/` stacks manage the shared resource group, state storage account, Log Analytics workspace, and Container Apps environment.
- `myapp-*` stacks manage individual Container Apps.

```text
live/
├── units/
│   ├── rg/
│   ├── storage-account/
│   ├── aca-env/
│   └── aca-app/
├── non-prod/
│   └── westeurope/
│       └── dev/
│           ├── platform-noncritical/
│           ├── myapp-1/
│           └── myapp-3/
└── prod/
    └── westeurope/
        └── prod/
            ├── platform-noncritical/
            └── myapp-1/
```

Reusable Terraform modules live under `modules/`, and reusable Terragrunt wrappers live under `live/units/`.

## Naming

- Resource group: `rg-<shared-stack>-<env>-<region>`
- Container Apps environment: `cae-<shared-stack>-<env>-<region>`
- Log Analytics workspace: `law-<shared-stack>-<env>-<region>`
- Container App: `ca-<app>-<env>-<region>`

Current shared stack token: `platform-noncritical`.
Current region short code: `weu`.

## Local Usage

Authenticate first:

```bash
az login
az account set --subscription "<subscription-id>"
```

Platform stack:

```bash
cd live/non-prod/westeurope/dev/platform-noncritical
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

App stack:

```bash
cd live/non-prod/westeurope/dev/myapp-3
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

Workload settings such as `container_image`, `min_replicas`, `max_replicas`, environment variables, and secret environment variables are versioned in each stack `terragrunt.stack.hcl`.

`secret_environment_variables` supports either a direct value or a Key Vault reference per secret:

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

Current workflows:

- [`.github/workflows/provision-platform.yml`](.github/workflows/provision-platform.yml): Terragrunt `plan` or `apply` for `platform-noncritical`
- [`.github/workflows/deploy-app.yml`](.github/workflows/deploy-app.yml): Terragrunt `plan` or `apply` for one app stack
- [`.github/workflows/deploy-aca-image.yml`](.github/workflows/deploy-aca-image.yml): image-only update for an existing Container App

The Terragrunt workflows do not reuse saved plan files. `apply` recalculates inputs on each run, which avoids bootstrap problems with mocked dependency outputs.

The ACA image workflow does not create infrastructure. It only updates the image of an existing Container App. Terraform remains the owner of the app resource shape.

Required GitHub configuration:

- Secret: `AZURE_CLIENT_ID`
- Variables: `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

Recommended setup:

1. Create GitHub Environments named `dev` and `prod-weu`.
2. Add approvals for `prod-weu`.
3. Configure Azure federated credentials for those GitHub Environments.

## Docs

- [Terraform & Terragrunt Concepts](docs/terraform-terragrunt-concepts.md)
- [Terragrunt Architecture Guide](docs/terragrunt-architecture.md)
- [Azure & GitHub Actions Setup](docs/azure-github-actions-setup.md)
