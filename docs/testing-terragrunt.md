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
terragrunt run --all --non-interactive apply
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
overrides CPU and memory to `0.5` and `1Gi`. Replica limits are `0` to `2`.

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

## 5. Ideas: avoid repeating 50 workers per environment

These are ideas only. Nothing here is implemented or tested, and the example code
has not been run. Check it with `terragrunt stack generate` before relying on it.

### Unit and stack

- A **unit** is one thing that gets deployed, with its own state. Here,
  `units/aca-app` is a unit: it deploys one container app.
- A **stack** is a collection of units. `stacks/pulse-api` is a stack that holds
  one unit. A stack file can hold as many `unit` blocks as you want.
- The **live** folder picks a stack and gives it values for that environment.

```text
live file  ->  stack  ->  unit(s)  ->  Terraform module
```

The block type follows the `source` folder: a folder with `terragrunt.hcl` is a
unit (`unit` block), a folder with `terragrunt.stack.hcl` is a stack (`stack`
block). Terragrunt's docs describe the same model, including nested stacks.

### Situation

50 workers that are identical except for the queue name, deployed in dev and
prod. Copying the 50 blocks into every environment means every change is many
edits.

### Plan: one stack with 50 units, written once

```text
stacks/workers/      ONE stack: 50 unit blocks, one per queue, shared settings in locals
live/dev/workers/    tiny file: "use stacks/workers" + dev values
live/prod/workers/   tiny file: "use stacks/workers" + prod values
```

`stacks/workers/terragrunt.stack.hcl` (written once):

```hcl
locals {
  common = {
    resource_group_name = "rg-platform-${local.environment}-${local.location_short}"
    container_image     = "ghcr.io/glexposito/pulse-api:latest"
    container_cpu       = try(values.container_cpu, 0.25)
    max_replicas        = try(values.max_replicas, 1)
    # ingress, probes, ...
  }
}

unit "worker-orders" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/units/aca-app"
  path   = "worker-orders"

  values = merge(
    local.common,
    {
      name        = "worker-orders"
      queue_scale = { queue_name = "orders", storage_account_name = values.storage_account_name }
    },
    try(values.orders, {})   # overrides for this worker only, empty if none
  )
}

# ...one unit block per worker
```

`live/prod/.../workers/terragrunt.stack.hcl` (one per environment):

```hcl
stack "workers" {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/stacks/workers"
  path   = "workers"

  values = {
    storage_account_name = "stprodqueues01"
    max_replicas         = 10        # default for all workers

    orders = {                       # only worker-orders
      max_replicas = 30
      queue_scale = {                # replaces the whole queue_scale
        storage_account_name = "stprodqueues01"
        queue_name           = "orders"
        queue_length         = 20
      }
    }
  }
}
```

### How overriding works

Later maps win in `merge`, so a worker gets its values in this order:

1. `local.common`: defaults for every worker (the live file can change these for
   all workers with `try(values.x, default)`).
2. The unit's own values: its name and queue.
3. `try(values.orders, {})`: what the live file sets for this worker only.

`merge` is shallow: setting `queue_scale` for a worker replaces the whole object,
so give it every field. That is fine here.

### Things to know

- Each unit needs a unique label and a unique `path`. The `path` is the
  generated folder and part of the state key.
- Terragrunt has no loop for `unit` blocks (not in the docs), so the 50 blocks are
  written out. If that is too much, generate `stacks/workers` from a list of
  queue names with a script.
- Each unit needs the `aca-env` dependency (`autoinclude`). Repeat it per unit or
  build it once in a local. Not tested whether `autoinclude` can share a local.
- Override keys in the live file must be plain identifiers (`orders`, not
  `worker-orders`).
- If a single-worker template is needed elsewhere, `stacks/worker` (one unit)
  can be nested inside a stack with a `stack` block. Nested stacks are supported.
- Container app names must be unique and at most 32 characters.
- Try 2 or 3 workers first. Run `terragrunt stack generate` and check the
  generated paths and values before writing all 50.

## 6. Clean up after testing

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
