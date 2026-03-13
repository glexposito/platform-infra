# Azure And GitHub Actions Setup

This repo uses Terragrunt to deploy Azure Container Apps environments from GitHub Actions with Azure OIDC.

## Repo Structure

This layout follows a common Terragrunt split:

- `modules/`: reusable Terraform modules
- `live/`: real environment stacks that point at actual infrastructure

In this repo:

- `modules/aca-status-page-updater`: reusable Azure Container Apps module
- `live/dev/status-page-updater`: dev deployment
- `live/stg/status-page-updater`: staging deployment
- `live/prod/status-page-updater`: production deployment

Azure resource names follow this pattern:

- `rg-<service>-<env>-<region>`
- `cae-<service>-<env>-<region>`
- `law-<service>-<env>-<region>`
- `ca-<service>-<env>-<region>`

Current conventions in this repo:

- service token: `spu`
- region code: `aue`

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

- `live/dev/status-page-updater/terraform.tfstate`
- `live/stg/status-page-updater/terraform.tfstate`
- `live/prod/status-page-updater/terraform.tfstate`

The backend values come from:

- `TG_STATE_RESOURCE_GROUP`
- `TG_STATE_STORAGE_ACCOUNT`
- `TG_STATE_CONTAINER`

Microsoft Learn backend reference:

- https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage

## Azure Side Setup

### 1. Choose Scope

Decide the narrowest Azure scope this deployment identity needs:

- best: target resource group per environment
- acceptable: shared resource group for this app
- avoid when possible: full subscription scope

### 2. Create The Terraform State Storage

The current repo assumes the backend already exists.

Example:

```bash
az group create \
  --name rg-aca-terraform-state \
  --location australiaeast

az storage account create \
  --name <globally-unique-storage-account> \
  --resource-group rg-aca-terraform-state \
  --location australiaeast \
  --sku Standard_LRS \
  --kind StorageV2

az storage container create \
  --name tfstate \
  --account-name <globally-unique-storage-account> \
  --auth-mode login
```

Then set these in GitHub:

- `TG_STATE_RESOURCE_GROUP`
- `TG_STATE_STORAGE_ACCOUNT`
- `TG_STATE_CONTAINER`

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
- `repo:glexposito/aca-infra:environment:stg`
- `repo:glexposito/aca-infra:environment:prod`

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

Repeat for `stg` and `prod`.

Microsoft Learn reference:

- https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust

### 6. Create GitHub Environments

Create these GitHub environments:

- `dev`
- `stg`
- `prod`

Recommended:

- require approvals for `prod`
- optionally require approvals for `stg`
- keep `dev` open for fast iteration

### 7. Add GitHub Secrets And Variables

Repository-level secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TG_STATE_RESOURCE_GROUP`
- `TG_STATE_STORAGE_ACCOUNT`
- `TG_STATE_CONTAINER`

Environment-level secret:

- `STATUSPAGE_API_KEY`

Environment-level variables:

- `AZURE_LOCATION`
- `STATUS_PAGE_UPDATER_IMAGE`
- `STATUS_PAGE_UPDATER_REGISTRY_SERVER` (optional)
- `STATUS_PAGE_UPDATER_ACR_ID` (optional)
- `TERRAFORM_VERSION` (optional)
- `TERRAGRUNT_VERSION` (optional)

Keep workload-specific values on the GitHub environment, not globally, so `dev`, `stg`, and `prod` can differ without changing the workflow.

## Local Testing

Before testing GitHub Actions, test locally with your Azure account:

```bash
az login
az account set --subscription "<subscription-id>"

export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export AZURE_TENANT_ID="<tenant-id>"
export TG_STATE_RESOURCE_GROUP="<state-rg>"
export TG_STATE_STORAGE_ACCOUNT="<state-storage-account>"
export TG_STATE_CONTAINER="tfstate"

export STATUS_PAGE_UPDATER_IMAGE="ghcr.io/example/status-page-updater:dev"
export STATUSPAGE_API_KEY="replace-me"

cd live/dev/status-page-updater
terragrunt init
terragrunt plan
```

If local `plan` works, test GitHub Actions against `dev` first.

## Workflow Usage

Manual dispatch supports:

- `targets=dev`
- `targets=stg`
- `targets=prod`
- `targets=dev,stg`

The workflow intentionally rejects `apply` when `prod` is mixed with other environments.

## Logging And Cost

This repo currently keeps:

- `dev`: 4 days
- `stg`: 4 days
- `prod`: 30 days

These are Log Analytics retention settings, not log volume caps.

Cost is driven mostly by ingestion volume, so the biggest cost lever is keeping the application logs quiet:

- avoid noisy heartbeat logs
- avoid debug-level logs in `prod`
- log errors and important lifecycle events

Relevant references:

- Log retention: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/data-retention-configure
- Log cost: https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs

## Notes

- GitHub Actions runners are ephemeral, so `terragrunt init` must run on every workflow execution.
- `init` does not recreate Azure resources. It initializes the backend, providers, and working directory for that run.
- If `acr_id` is used, the deployment identity needs enough permission to create the `AcrPull` role assignment.
