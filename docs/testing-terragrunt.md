# Testing Terragrunt in Azure

My local walkthrough for testing this repo in **Southeast Asia** and
**New Zealand North**, using **fish**.
I create the state storage with Azure CLI, then deploy the platform and Pulse API
with Terragrunt.

The current live configuration creates a resource group, Log Analytics workspace,
Container Apps environment, and Pulse API. Run each step in order and stop if a
command fails. Azure usage can incur charges; cleanup is at the end.

## 1. Requirements

You need these installed:

- Azure CLI (`az`)
- Terraform
- Terragrunt

```sh
az login
az account set --subscription "<your-subscription-id>"
```

The subscription state must be `Enabled` before creating resources. Check it
with `az account show`.

## 2. Create the state storage with Azure CLI

These names match [live/non-prod/backend.hcl](../live/non-prod/backend.hcl):

| Resource          | Name                     |
| ----------------- | ------------------------ |
| Resource group    | `rg-aca-terraform-state` |
| Storage account   | `glexpositotfstate01`    |
| Private container | `tfstate`                |

For a fresh setup, check the storage account name first:

```fish
az storage account check-name --name glexpositotfstate01
```

Continue when `nameAvailable` is `true`. Storage account names are unique across
all of Azure. If the name is taken, choose another and update
`state_storage_account` in `backend.hcl` to match. If you already created this
account in your own subscription, reuse it.

Register the providers needed for state storage and Container Apps:

```fish
az provider register --namespace Microsoft.Storage --wait
and az provider register --namespace Microsoft.App --wait
and az provider register --namespace Microsoft.OperationalInsights --wait
```

These are the providers listed in Microsoft's [Container Apps setup instructions](https://learn.microsoft.com/en-us/azure/container-apps/tutorial-event-driven-jobs#prepare-the-environment).

Create the backend:

```fish
az group create \
  --name rg-aca-terraform-state \
  --location southeastasia

and az storage account create \
  --name glexpositotfstate01 \
  --resource-group rg-aca-terraform-state \
  --location southeastasia \
  --sku Standard_LRS \
  --kind StorageV2

and az storage container-rm create \
  --name tfstate \
  --storage-account glexpositotfstate01 \
  --resource-group rg-aca-terraform-state \
  --public-access off
```

## 3. Deploy

Terragrunt only runs what is inside the folder you are in. Every deploy uses
the same commands, run one at a time:

```sh
terragrunt stack generate
terragrunt run --all init
terragrunt run --all plan
```

Read the plan. If it looks right, apply it:

```sh
terragrunt run --all apply
```

### First deploy: platform first, then Pulse API

Pulse API needs the platform to already exist, so deploy the platform first.
Otherwise the Pulse API plan fails with "Managed Environment ... was not found".

1. `cd live/non-prod/southeastasia/dev/platform` and run the commands above.
2. `cd ../pulse-api` and run the commands above.

For New Zealand, use `newzealandnorth` instead of `southeastasia`.

### After the platform exists

You can run everything at once, and Terragrunt applies the platform first:

- Only Southeast Asia: `cd live/non-prod/southeastasia/dev`
- Only New Zealand: `cd live/non-prod/newzealandnorth/dev`
- All regions: `cd live/non-prod`

Then run the commands above.

The [live stack](../live/non-prod/southeastasia/dev/pulse-api/terragrunt.stack.hcl)
uses the [shared Pulse API stack](../stacks/pulse-api/terragrunt.stack.hcl) and
overrides CPU and memory to `0.5` and `1Gi`. Replica limits are `0` to `1`.

## 4. Check the app and state

Get the app hostname:

```fish
az containerapp show \
  --name ca-pulse-api-dev-sea \
  --resource-group rg-platform-dev-sea \
  --query properties.configuration.ingress.fqdn --output tsv
```

Open `https://<returned-hostname>/live` and `/ready`. The first request can take
longer when the app has scaled to zero.

In the Azure portal, open **Storage accounts → glexpositotfstate01 → Containers →
tfstate**. After successful deployment, the state blob names are:

```text
platform/dev/southeastasia/platform/rg/terraform.tfstate
platform/dev/southeastasia/platform/aca-env/terraform.tfstate
platform/dev/southeastasia/pulse-api/app/terraform.tfstate
```

`terragrunt stack generate` generates configuration files. The state blobs track
the deployed resources and are managed by Terraform.

## 5. Clean up after testing

Go into the same folder you deployed from and run:

```sh
terragrunt run --all --no-auto-approve destroy
```

From a folder with both, Terragrunt destroys Pulse API before the platform. If
you destroy folder by folder, do `pulse-api` first, then `platform`.

Keep the state storage until both destroys finish successfully. If you are
finished with this backend, it contains no state needed by other deployments,
and you have saved any data you want to keep, delete its resource group last:

```fish
az group delete --name rg-aca-terraform-state
```

This also deletes the storage account and all state blobs inside it. To test
again after deleting it, repeat step 2.
