# Azure And GitHub Actions Setup

This repo uses Terragrunt to deploy Azure Container Apps environments from GitHub Actions with Azure OIDC.

## Repo Structure

This layout follows a common Terragrunt split:

- `modules/`: reusable Terraform modules
- `live/`: real environment stacks that point at actual infrastructure

In this repo:

- `modules/aca-app`: reusable Azure Container Apps module
- `live/non-prod/westeurope/dev`: dev deployment root
- `live/prod/westeurope/prod`: production deployment root for West Europe

Azure resource names follow this pattern:

- `rg-<shared-stack>-<env>-<region>`
- `cae-<shared-stack>-<env>-<region>`
- `law-<shared-stack>-<env>-<region>`
- `ca-<app>-<env>-<region>`

Current conventions in this repo:

- shared stack token: `platform-noncritical`
- app token: `myapp`
- region code: `weu`

`live` is a standard Terragrunt convention. It means these stacks are the concrete deployments, not reusable building blocks.

## How Authentication Works

There are two separate authentication paths:

1. Local development
   - `az login`
   - Terraform/Terragrunt uses your Azure CLI session

2. GitHub Actions
   - GitHub issues a short-lived OIDC token
   - Azure trusts that token through a federated credential
   - `azure/login@v2` exchanges it for an Azure access token

This avoids storing a long-lived Azure client secret in GitHub.

Official references:

- GitHub OIDC with Azure: https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure
- Microsoft Learn OIDC setup: https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect
- Azure Login action: https://github.com/marketplace/actions/azure-login

## Terraform State

Terraform state is stored in Azure Storage using the `azurerm` backend from the root [root.hcl](/home/guille/dev/aca-infra/root.hcl).

Each environment gets a separate state key based on the stack path:

- `live/non-prod/westeurope/dev/app-env/terraform.tfstate`
- `live/non-prod/westeurope/dev/myapp/terraform.tfstate`
- `live/prod/westeurope/prod/app-env/terraform.tfstate`
- `live/prod/westeurope/prod/myapp/terraform.tfstate`

The backend values are versioned in `live/*/backend.hcl` and read by the root [root.hcl](/home/guille/dev/aca-infra/root.hcl).

This repo includes [init-azure-state.sh](/home/guille/dev/aca-infra/scripts/init-azure-state.sh) to bootstrap the backend resource group, storage account, and blob container.

Example:

```bash
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export STATE_SA="<globally-unique-storage-account>"

./scripts/init-azure-state.sh
```

Script defaults:

- `LOCATION=westeurope`
- `STATE_RG=rg-aca-terraform-state`
- `STATE_CONTAINER=tfstate`

The script prints shell exports such as `TG_STATE_RESOURCE_GROUP`, `TG_STATE_STORAGE_ACCOUNT`, and `TG_STATE_CONTAINER`. Use those values to populate the checked-in backend settings in `live/*/backend.hcl`.

Microsoft Learn backend reference:

- https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage

## Azure Side Setup

## Quick Start Script

This repo includes [init-azure-oidc.sh](/home/guille/dev/aca-infra/scripts/init-azure-oidc.sh) to bootstrap the Microsoft Entra app, service principal, Azure role assignment, and GitHub OIDC federated credential.

Required environment variables:

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `GITHUB_OWNER`
- `GITHUB_REPO`

Common optional environment variables:

- `APP_NAME` default: `aca-infra-gha`
- `ENV_NAME` default: `dev`
- `ROLE_NAME` default: `Contributor`
- `ROLE_SCOPE` default: `/subscriptions/$AZURE_SUBSCRIPTION_ID`
- `FEDERATED_CRED_NAME` default: `github-$ENV_NAME`

Example:

```bash
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export AZURE_TENANT_ID="<tenant-id>"
export GITHUB_OWNER="<owner>"
export GITHUB_REPO="aca-infra"
export ENV_NAME="dev"

./scripts/init-azure-oidc.sh
```

The script prints the values to store in GitHub configuration:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Store them as:

- repository secret: `AZURE_CLIENT_ID`
- repository or environment variable: `AZURE_TENANT_ID`
- repository or environment variable: `AZURE_SUBSCRIPTION_ID`

Use the manual steps below if you want to create or scope each Azure object yourself instead of using the helper script.

### 1. Choose Scope

Decide the narrowest Azure scope this deployment identity needs:

- best: target resource group per environment
- acceptable: shared resource group for this app
- avoid when possible: full subscription scope

### 2. Create The Terraform State Storage

The current repo assumes the backend already exists.

If you want the fast path, use [init-azure-state.sh](/home/guille/dev/aca-infra/scripts/init-azure-state.sh). The manual commands below are the equivalent fallback.

Example:

```bash
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export STATE_SA="<globally-unique-storage-account>"
export LOCATION="westeurope"
export STATE_RG="rg-aca-terraform-state"
export STATE_CONTAINER="tfstate"

az account set --subscription "${AZURE_SUBSCRIPTION_ID}"

az group create \
  --subscription "${AZURE_SUBSCRIPTION_ID}" \
  --name "${STATE_RG}" \
  --location "${LOCATION}"

az storage account create \
  --subscription "${AZURE_SUBSCRIPTION_ID}" \
  --name "${STATE_SA}" \
  --resource-group "${STATE_RG}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2

az storage container create \
  --subscription "${AZURE_SUBSCRIPTION_ID}" \
  --name "${STATE_CONTAINER}" \
  --account-name "${STATE_SA}" \
  --auth-mode login
```

Then copy these values into the relevant `backend.hcl` file:

- `state_resource_group`
- `state_storage_account`
- `state_container`

### 3. Create A Microsoft Entra App For GitHub Actions

Example:

```bash
az ad app create --display-name aca-infra-github
```

Capture the returned:

- `appId`: use as `AZURE_CLIENT_ID`

Then create the service principal:

```bash
az ad sp create --id <appId>
```

Get the tenant and subscription IDs:

```bash
az account show --query '{subscriptionId:id, tenantId:tenantId}' -o json
```

Use those as:

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

### 4. Grant Azure Roles

Grant only the minimum roles required at the target scope.

At minimum, the deployment identity needs permission to create and manage:

- resource groups if this repo is allowed to create them
- Log Analytics workspaces
- Container Apps environments
- Container Apps
- role assignments if using ACR pull assignment

If you keep the current module behavior, the identity also needs permission to create role assignments when `acr_id` is set.

Example at resource-group scope:

```bash
az role assignment create \
  --role Contributor \
  --assignee-object-id <service-principal-object-id> \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>
```

If the workflow needs to assign `AcrPull`, add:

```bash
az role assignment create \
  --role "User Access Administrator" \
  --assignee-object-id <service-principal-object-id> \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>
```

Be careful with `User Access Administrator`. Scope it as narrowly as possible.

The state backend may also need storage data access depending on your backend auth path.

### 5. Add Federated Credentials For GitHub Environments

This is the OIDC trust setup.

Because the workflow uses GitHub `environment`s, the subject should match this pattern:

```text
repo:<owner>/<repo>:environment:<environment-name>
```

Examples:

- `repo:glexposito/aca-infra:environment:dev`
- `repo:glexposito/aca-infra:environment:prod-weu`

Create one federated credential per environment.

Example credential file for `dev`:

```json
{
  "name": "github-dev",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<owner>/<repo>:environment:dev",
  "description": "GitHub Actions OIDC for dev",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
```

Create it:

```bash
az ad app federated-credential create \
  --id <app-object-id> \
  --parameters github-dev.json
```

Repeat for `prod-weu`.

Microsoft Learn reference:

- https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust

### 6. Create GitHub Environments

Create these GitHub environments:

- `dev`
- `prod-weu`

Recommended:

- require approvals for `prod-weu`
- keep `dev` open for fast iteration

### 7. Add GitHub Secrets And Variables

Repository-level secrets:

- `AZURE_CLIENT_ID`

Repository-level variables:

- `AZURE_TENANT_ID` or environment-level `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID` or environment-level `AZURE_SUBSCRIPTION_ID`

Environment-level secrets:

- `STATUSPAGE_API_KEY`

Terraform and Terragrunt versions are pinned directly in the workflow file.

## Local Testing

Before testing GitHub Actions, test locally with your Azure account:

```bash
az login
az account set --subscription "<subscription-id>"

export STATUSPAGE_API_KEY="replace-me"

cd live/non-prod/westeurope/dev
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive plan -- -no-color
```

If local `plan` works, test GitHub Actions against `dev` first.

## Workflow Usage

The workflow is manual-only and `workflow_dispatch` supports:

- `targets=dev`
- `targets=prod-weu`

The workflow intentionally rejects `apply` when a `prod-*` target is mixed with other environments.

## Logging And Cost

This repo currently keeps:

- `dev`: 30 days
- `prod-weu`: 30 days

These are Log Analytics retention settings, not log volume caps.

Cost is driven mostly by ingestion volume, so the biggest cost lever is keeping the application logs quiet:

- avoid noisy heartbeat logs
- avoid debug-level logs in production
- log errors and important lifecycle events

Relevant references:

- Log retention: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/data-retention-configure
- Log cost: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs

## Notes

- GitHub Actions runners are ephemeral, so `terragrunt init` must run on every workflow execution.
- `init` does not recreate Azure resources. It initializes the backend, providers, and working directory for that run.
- The workflow runs from the environment root and uses `terragrunt run --all --non-interactive ...` so `app-env` is applied before `myapp`.
- If `acr_id` is used, the deployment identity needs enough permission to create the `AcrPull` role assignment.
- This repository is a PoC. For quick resets in a disposable test subscription, it can be reasonable to delete both Azure resources and matching backend state for `dev`, but that is not a safe practice for persistent environments.
