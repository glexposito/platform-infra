# platform-infra

Lean Terragrunt proof of concept for Azure platform and app infrastructure on Azure Container Apps.

> [!WARNING]
> This repository is a proof of concept for a disposable Azure account.
> Expect refactors, rebuilds, and manual cleanup while the layout is still evolving.

## What It Does

- `platform-nc/` manages shared Azure resources.
- app stack folders manage one Container App per stack.

```text
live/
├── non-prod/
│   └── southeastasia/
│       └── dev/
│           ├── platform-nc/   # flat Terragrunt units, no terragrunt.stack.hcl
│           ├── <app-stack>/   # terragrunt.stack.hcl, generated via `terragrunt stack generate`
│           └── ...
units/
├── aca-app/
├── aci-app/
└── storage-account/
```

Reusable Terraform modules live in `modules/`. Reusable Terragrunt wrappers live in `units/` when reused across multiple stacks; `platform-nc`'s units (`rg`, `aca-env`, `aks`, `envoy-gateway`, `envoy-gateway-config`, `argocd`, `argocd-bootstrap`) are only ever instantiated once, so they're written directly as plain Terragrunt directories under `platform-nc/` instead of going through the `units/` + Stacks indirection.

## Naming

- Resource group: `rg-<shared-stack>-<env>-<region>`
- Container Apps environment: `cae-<shared-stack>-<env>-<region>`
- Log Analytics workspace: `law-<shared-stack>-<env>-<region>`
- Container App: `ca-<app>-<env>-<region>`

Current shared stack token: `platform-nc`  
Current region short code: `sea`

## Local Usage

Authenticate first:

```bash
az login
az account set --subscription "<subscription-id>"
```

Deploy the platform stack (plain Terragrunt units, no `stack generate` step):

```bash
cd live/non-prod/southeastasia/dev/platform-nc
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

- [`.github/workflows/provision-platform.yml`](.github/workflows/provision-platform.yml) runs Terragrunt for `platform-nc`
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
