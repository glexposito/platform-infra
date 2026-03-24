# Terragrunt Layout

The live layout is intentionally small:

- environment group: `live/non-prod`
- region: `westeurope`
- environment: `dev`
- stack: `platform-noncritical`, `myapp-*`
- reusable units: `live/units/*`

```text
live/
├── units/
│   ├── rg/
│   ├── storage-account/
│   ├── aca-env/
│   └── aca-app/
└── <environment-group>/<region>/<environment>/<stack>
```

## Stack Split

`platform-noncritical` owns shared resources:

- resource group
- state storage account
- Log Analytics workspace
- Container Apps environment

Each `myapp-*` stack owns one Container App and its app-specific settings.

## Composition

Each stack defines a `terragrunt.stack.hcl`, which generates one or more units:

- platform stack: `rg`, `storage-account`, `aca-env`
- app stack: `app`

Generated units include [root.hcl](/home/guille/dev/platform-infra/root.hcl) and read `region.hcl`.

## Dependencies

Platform units depend on the resource group and use `mock_outputs` so non-apply commands can still run before real state exists.

App stacks can either:

- pass `resource_group_name` and `container_app_environment_name`
- or pass `platform_path` and consume outputs from the platform stack

Current live app stacks use explicit values.
