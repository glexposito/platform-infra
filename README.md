# aca-infra

Terragrunt/Terraform scaffold for deploying a containerized status-page updater to Azure Container Apps in `dev`, `stg`, and `prod`.

## Layout

- `modules/aca-status-page-updater`: reusable Azure Container Apps module
- `live/dev/status-page-updater`: development stack
- `live/stg/status-page-updater`: staging stack
- `live/prod/status-page-updater`: production stack

Current log retention:

- `dev`: 4 days
- `stg`: 4 days
- `prod`: 30 days

Azure naming convention used by the stacks:

- resource group: `rg-<service>-<env>-<region>`
- container apps environment: `cae-<service>-<env>-<region>`
- log analytics workspace: `law-<service>-<env>-<region>`
- container app: `ca-<service>-<env>-<region>`

Current service token and region code:

- service: `spu` for status page updater
- region: `aue` for Australia East

## Required environment variables

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `TG_STATE_RESOURCE_GROUP`
- `TG_STATE_STORAGE_ACCOUNT`
- `TG_STATE_CONTAINER`

## Workload-specific environment variables

- `STATUS_PAGE_UPDATER_IMAGE`
- `STATUS_PAGE_UPDATER_REGISTRY_SERVER` (optional)
- `STATUS_PAGE_UPDATER_ACR_ID` (optional)
- `STATUSPAGE_API_KEY`

## Example

```bash
cd live/dev/status-page-updater
terragrunt init
terragrunt plan
terragrunt apply
```

## GitHub Actions

The workflow is in [`.github/workflows/provision-aca-status-page-updater-infra.yml`](/home/guille/dev/aca-infra/.github/workflows/provision-aca-status-page-updater-infra.yml).
Detailed setup notes are in [docs/azure-github-actions-setup.md](/home/guille/dev/aca-infra/docs/azure-github-actions-setup.md).
An Azure backend bootstrap helper is in [scripts/init-azure-state.sh](/home/guille/dev/aca-infra/scripts/init-azure-state.sh).
An Azure OIDC bootstrap helper is in [scripts/init-azure-oidc.sh](/home/guille/dev/aca-infra/scripts/init-azure-oidc.sh).

Manual dispatch supports comma-separated targets such as `dev`, `stg`, `prod`, or `dev,stg`.
`prod` apply is intentionally restricted to run by itself.

Required GitHub secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TG_STATE_RESOURCE_GROUP`
- `TG_STATE_STORAGE_ACCOUNT`
- `TG_STATE_CONTAINER`
- `STATUSPAGE_API_KEY`

Recommended GitHub environment or repository variables:

- `AZURE_LOCATION`
- `TERRAFORM_VERSION`
- `TERRAGRUNT_VERSION`
- `STATUS_PAGE_UPDATER_IMAGE`
- `STATUS_PAGE_UPDATER_REGISTRY_SERVER`
- `STATUS_PAGE_UPDATER_ACR_ID`

Recommended security setup:

- Create GitHub environments named `dev`, `stg`, and `prod`
- Add approval rules for `prod`
- Put `STATUSPAGE_API_KEY`, `STATUS_PAGE_UPDATER_IMAGE`, and optional registry settings on each GitHub environment
- Configure Azure federated credentials to trust the repo and those environments
