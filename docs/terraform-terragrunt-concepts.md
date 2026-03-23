# Terraform And Terragrunt

This repo uses Terraform for Azure resources and Terragrunt for stack composition.

## Terraform

Terraform owns the actual infrastructure:

- [modules/aca-environment](/home/guille/dev/platform-infra/modules/aca-environment) creates the Log Analytics workspace and Container Apps environment
- [modules/aca-app](/home/guille/dev/platform-infra/modules/aca-app) creates one Container App and optional `AcrPull` role assignment

Remote state is configured from [root.hcl](/home/guille/dev/platform-infra/root.hcl).

## Terragrunt

Terragrunt handles:

- backend and provider generation
- per-stack inputs
- dependency wiring
- repeated wrappers under [live/units](/home/guille/dev/platform-infra/live/units)

Each stack root has a `terragrunt.stack.hcl`.

- Platform stack: `rg`, `storage-account`, `aca-env`
- App stack: `app`

## Ownership

Terraform remains the source of truth for:

- shared platform resources
- Container Apps
- scale settings
- environment variables and secrets
