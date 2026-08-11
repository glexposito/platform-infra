# Terragrunt Layout

The live layout is intentionally small:

- environment group: `live/non-prod`
- region: `southeastasia`
- environment: `dev`
- stack: `platform-nc`, `myapp-*`
- reusable units: `units/*`

```text
live/
└── <environment-group>/<region>/<environment>/<stack>

units/
├── rg/
├── aca-env/
└── aca-app/
```

## Stack Split

`platform-nc` owns shared resources:

- resource group
- Log Analytics workspace
- Container Apps environment

Each `myapp-*` stack owns one Container App and its app-specific settings.

## Composition

Each stack defines a `terragrunt.stack.hcl`, which generates one or more units:

- platform stack: `rg`, `aca-env`
- app stack: `app`

Generated units include [root.hcl](/home/guille/dev/platform-infra/root.hcl) and read `region.hcl`.

## Dependencies

Platform units depend on the resource group and use `mock_outputs` so non-apply commands can still run before real state exists.

Current live app stacks pass explicit values such as:

- `resource_group_name`
- `container_app_environment_name`
- `container_image`
- optional `ingress`
- optional `liveness_probes`, `readiness_probes`, and `startup_probes`
