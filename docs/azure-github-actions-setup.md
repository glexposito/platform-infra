# Azure And GitHub Actions Setup

This repo uses GitHub OIDC plus `azure/login@v2` to run Terragrunt against Azure without storing a long-lived client secret in GitHub.

## Workflows

- [`.github/workflows/provision-platform.yml`](/home/guille/dev/platform-infra/.github/workflows/provision-platform.yml)
  Runs Terragrunt `plan` or `apply` against:
  - `live/non-prod/westeurope/dev/platform-noncritical`
  - `live/prod/westeurope/prod/platform-noncritical`

- [`.github/workflows/deploy-app.yml`](/home/guille/dev/platform-infra/.github/workflows/deploy-app.yml)
  Runs Terragrunt `plan` or `apply` against one app stack:
  - `live/non-prod/westeurope/dev/<app>`
  - `live/prod/westeurope/prod/<app>`

- [`.github/workflows/deploy-aca-image.yml`](/home/guille/dev/platform-infra/.github/workflows/deploy-aca-image.yml)
  Updates only the image of an existing Container App with `az containerapp update --image ...`.

The Terragrunt workflows do not reuse saved plan files. `apply` recalculates from the stack on each run.

## GitHub Configuration

Required GitHub configuration:

- Secret: `AZURE_CLIENT_ID`
- Variables: `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

Recommended GitHub setup:

1. Create GitHub Environments named `dev` and `prod-weu`.
2. Add approvals for `prod-weu`.
3. Scope your federated credentials to those environments.

## Azure OIDC Bootstrap

This repo includes helper scripts:

- [scripts/init-azure-state.sh](/home/guille/dev/platform-infra/scripts/init-azure-state.sh)
- [scripts/init-azure-oidc.sh](/home/guille/dev/platform-infra/scripts/init-azure-oidc.sh)

Typical bootstrap flow:

```bash
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export AZURE_TENANT_ID="<tenant-id>"
export GITHUB_OWNER="<owner>"
export GITHUB_REPO="platform-infra"

./scripts/init-azure-state.sh
./scripts/init-azure-oidc.sh
```

Store the printed values as:

- `AZURE_CLIENT_ID` as a GitHub secret
- `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` as GitHub variables

## Permissions

At minimum, the deployment identity needs permission to manage:

- resource groups used by this repo
- storage accounts and blob containers for Terraform state
- Log Analytics workspaces
- Container Apps environments
- Container Apps

If app stacks use `acr_id`, the identity also needs permission to create role assignments for `AcrPull`.

## Notes

- GitHub Actions runners are ephemeral, so each workflow runs `terragrunt init`.
- `deploy-aca-image.yml` is intentionally image-only. It assumes the Container App already exists and is managed by Terraform.
- If you want CI/CD to create Container Apps, that becomes a different ownership model and should not overlap with Terraform ownership of the same app.
