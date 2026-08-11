# Terragrunt Layout

The live layout is intentionally small:

- environment group: `live/non-prod`
- region: `southeastasia`
- environment: `dev`
- stack: `platform-nc`, `pulse-api` (and future app stacks)
- reusable units: `units/*`

```text
live/
└── <environment-group>/<region>/<environment>/<stack>

units/
├── aca-app/
├── aci-app/
└── storage-account/
```

## Stack Split

`platform-nc` owns shared resources: resource group, Log Analytics workspace, Container Apps environment, AKS cluster, and the cluster platform stack (Envoy Gateway ingress, Argo CD).

Each app stack (e.g. `pulse-api`) owns one Container App and its app-specific settings.

## Composition

`platform-nc` is a flat set of plain Terragrunt units (`rg`, `aca-env`, `aks`, `envoy-gateway`, `envoy-gateway-config`, `argocd`, `argocd-bootstrap`), each a real directory with its own `terragrunt.hcl` — no `terragrunt.stack.hcl`, no `terragrunt stack generate` step. Every one of those units is only ever instantiated once, so there's no reuse to gain from routing them through `units/` + Stacks; sibling units reference each other directly via relative `dependency` paths (e.g. `../rg`, `../aks`).

App stacks (`pulse-api` and future ones) still use `terragrunt.stack.hcl` + `terragrunt stack generate`, since the whole point there is reusing the same `units/aca-app` template across many app stacks.

Every unit includes [root.hcl](/home/guille/dev/platform-infra/root.hcl) and reads `region.hcl`.

## Dependencies

Platform units depend on the resource group and use `mock_outputs` so non-apply commands can still run before real state exists.

Current live app stacks pass explicit values such as:

- `resource_group_name`
- `container_app_environment_name`
- `container_image`
- optional `ingress`
- optional `liveness_probes`, `readiness_probes`, and `startup_probes`
