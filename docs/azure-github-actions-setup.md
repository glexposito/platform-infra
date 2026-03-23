# Azure And GitHub Actions

This repo uses GitHub OIDC with `azure/login@v2` so GitHub Actions can deploy to Azure without a long-lived client secret.

## Workflows

- [`.github/workflows/provision-platform.yml`](/home/guille/dev/platform-infra/.github/workflows/provision-platform.yml) runs Terragrunt for `platform-noncritical`
- [`.github/workflows/deploy-app.yml`](/home/guille/dev/platform-infra/.github/workflows/deploy-app.yml) runs Terragrunt for one app stack

Terragrunt workflows do not reuse saved plan files. Each `apply` recalculates from the stack.

## GitHub Setup

Required configuration:

- secret: `AZURE_CLIENT_ID`
- variables: `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

Recommended:

1. Create GitHub Environments `dev` and `prod-weu`.
2. Add approvals for `prod-weu`.
3. Scope federated credentials to those environments.

## Bootstrap

Helper scripts:

- [scripts/init-azure-state.sh](/home/guille/dev/platform-infra/scripts/init-azure-state.sh)
- [scripts/init-azure-oidc.sh](/home/guille/dev/platform-infra/scripts/init-azure-oidc.sh)

Typical flow:

```bash
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export AZURE_TENANT_ID="<tenant-id>"
export GITHUB_OWNER="<owner>"
export GITHUB_REPO="platform-infra"

./scripts/init-azure-state.sh
./scripts/init-azure-oidc.sh
```

Save the outputs as:

- `AZURE_CLIENT_ID` in GitHub Secrets
- `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` in GitHub Variables
