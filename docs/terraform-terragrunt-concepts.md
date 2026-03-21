# Terraform And Terragrunt Concepts

This repo uses Terraform modules plus Terragrunt stack wrappers.

## Terraform

Terraform manages the Azure resources themselves.

In this repo:

- [modules/aca-environment](/home/guille/dev/platform-infra/modules/aca-environment) manages:
  - Log Analytics workspace
  - Container Apps environment

- [modules/aca-app](/home/guille/dev/platform-infra/modules/aca-app) manages:
  - Container App
  - optional `AcrPull` role assignment

Terraform state is stored remotely in Azure Storage through the backend generated from [root.hcl](/home/guille/dev/platform-infra/root.hcl).

## Terragrunt

Terragrunt handles:

- shared backend and provider generation
- stack composition
- dependency wiring between units
- per-stack remote state keys

Reusable Terragrunt wrappers live under [live/units](/home/guille/dev/platform-infra/live/units).

## Stack Model

Each stack root contains a `terragrunt.stack.hcl`.

Examples:

- [live/non-prod/westeurope/dev/platform-noncritical/terragrunt.stack.hcl](/home/guille/dev/platform-infra/live/non-prod/westeurope/dev/platform-noncritical/terragrunt.stack.hcl)
- [live/non-prod/westeurope/dev/myapp-3/terragrunt.stack.hcl](/home/guille/dev/platform-infra/live/non-prod/westeurope/dev/myapp-3/terragrunt.stack.hcl)

The platform stack generates:

- `rg`
- `storage-account`
- `aca-env`

An app stack generates:

- `app`

## Dependencies And Mocks

Platform units use Terragrunt `dependency` blocks plus `mock_outputs` so non-apply commands can work before the resource group exists.

The app unit supports:

- explicit inputs for `resource_group_name` and `container_app_environment_name`
- optional dependency-based wiring through `platform_path`

The current live app stacks pass explicit values, so Terraform looks up the existing Container Apps environment by name at apply time.

## Typical Flow

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

## Ownership Rule

Terraform is the owner of:

- shared platform resources
- Container App resources
- scale settings
- environment variables and secrets

The image workflow under [deploy-aca-image.yml](/home/guille/dev/platform-infra/.github/workflows/deploy-aca-image.yml) only updates the image of an already-existing Container App. It does not create or define the app.
