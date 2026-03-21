# Terragrunt Architecture

This repo follows a small Terragrunt live-layout split:

- top-level environment group: `live/non-prod`, `live/prod`
- region: `westeurope`
- environment: `dev`, `prod`
- stack: `platform-noncritical`, `myapp-1`, `myapp-3`
- shared unit wrappers: `live/units/*`

## Structure

```text
live/
├── units/
│   ├── rg/
│   ├── storage-account/
│   ├── aca-env/
│   └── aca-app/
└── <environment-group>/<region>/<environment>/<stack>
```

`platform-noncritical` is the shared platform stack.
`myapp-*` folders are app stacks.

## Ownership

Platform stack:

- resource group
- storage account used by the platform stack
- Log Analytics workspace
- Container Apps environment

App stacks:

- one Container App per stack
- image reference
- scale settings
- environment variables and secrets
- optional ACR pull assignment

This separation is intentional. Platform resources change less often and are shared. App resources change more often and should stay isolated per app.

## How Stacks Compose

Stack folders contain `terragrunt.stack.hcl`.
Those stack files generate units such as:

- `rg`
- `storage-account`
- `aca-env`
- `app`

The generated units all include [root.hcl](/home/guille/dev/platform-infra/root.hcl) for provider and backend config, and they read `region.hcl` from their generated location.

## Dependencies

The platform stack has explicit Terragrunt dependencies:

- `storage-account` depends on `rg`
- `aca-env` depends on `rg`

Those unit wrappers use `mock_outputs` for non-apply commands so `init`, `validate`, and `plan` can still run before the dependency has real state.

App stacks can work in two ways:

- explicit wiring: pass `resource_group_name` and `container_app_environment_name`
- dependency wiring: pass `platform_path` and consume platform outputs

The current live app stacks use explicit wiring, so they do not require a Terragrunt dependency on the platform stack.

## Add A New App

1. Create a new stack folder next to the existing app folders.
2. Copy an existing app `terragrunt.stack.hcl`.
3. Set the app name, image, and scale values.
4. Run Terragrunt from that stack root.

Example:

```bash
mkdir -p live/non-prod/westeurope/dev/user-api
cp live/non-prod/westeurope/dev/myapp-3/terragrunt.stack.hcl live/non-prod/westeurope/dev/user-api/
```

## Add A New Region

1. Create the new region and environment folders.
2. Add a `region.hcl` with `location` and `location_short`.
3. Copy the relevant stack files into the new region.
4. Deploy from the new stack root.

## Decommission A Stack

Do not delete stack folders first.

1. Run `terragrunt destroy` from the stack root.
2. Verify Azure resources are gone.
3. Remove the stack folder and update workflows if needed.

Example:

```bash
cd live/prod/westeurope/prod/platform-noncritical
terragrunt run --all --non-interactive destroy -- -auto-approve -no-color
```
