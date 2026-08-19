# Terragrunt Layout

The live layout is intentionally small:

- environment group: `live/non-prod`
- region: `southeastasia`
- environment: `dev`
- stack: `platform` (split into `rg`, `compute`, `workloads`), `pulse-api`, `<app-stack>`
- reusable units: `units/*`

```text
live/
└── <environment-group>/<region>/<environment>/
    ├── platform/
    │   ├── rg/
    │   ├── compute/
    │   └── workloads/
    └── <app-stack>/

units/
├── rg/
├── aca-env/
├── aca-app/
├── aci-app/
├── aks-cluster/
├── argocd/
└── storage-account/
```

## Stack Split

`platform` owns shared resources, split across three sub-stacks so each can be planned/applied independently:

- `platform/rg` — resource group
- `platform/compute` — Log Analytics workspace, Container Apps environment, AKS cluster
- `platform/workloads` — ArgoCD, deployed onto the AKS cluster

Each app stack (e.g. `pulse-api`) owns one Container App and its app-specific settings.

## Composition

Each stack directory defines a `terragrunt.stack.hcl`, which generates one or more units:

- `platform/rg`: `rg`
- `platform/compute`: `aca_env`, `aks`
- `platform/workloads`: `argocd`
- app stack: `pulse-api` (via the `aca-app` unit)

Generated units include [root.hcl](/home/guille/dev/platform-infra/root.hcl) and read `region.hcl`.

## Naming: state key vs resource naming

Each stack directory carries a small set of parent-folder config files —
`backend.hcl`, `region.hcl`, `env.hcl`, `stack.hcl` — that [root.hcl](/home/guille/dev/platform-infra/root.hcl)
reads via `find_in_parent_folders()` to build the remote state `key`:

```
platform/${environment}/${location}/${stack_name}/${unit}/terraform.tfstate
```

Separately, each `terragrunt.stack.hcl` passes a `values` block into the
units it generates (e.g. `values = { name = "platform" }` in
[platform/rg/terragrunt.stack.hcl](/home/guille/dev/platform-infra/live/non-prod/southeastasia/dev/platform/rg/terragrunt.stack.hcl)).
That `values.name` is what the generated unit (`units/rg/terragrunt.hcl`)
uses to name the actual Azure resource (e.g. `rg-platform-dev-sea`).

These two "name" values end up equal in practice but are declared
independently, and that's on purpose: `root.hcl` is `include`d by every
unit, but a Stacks `values` block is scoped to the specific unit instance
it was generated for — `root.hcl` has no way to read the `values` a unit
was instantiated with. `stack.hcl` exists purely as a file `root.hcl` *can*
read via `find_in_parent_folders()`, so the state key stays explicit and
stable even if the directory layout is reorganized later (see the comment
above `local.region_vars` in `root.hcl`).

**Consequence:** if you rename a stack, update it in both places — the
stack's `stack.hcl` (state key) and every `terragrunt.stack.hcl` under it
that sets `values.name` (resource naming) — or the state key and the
resource names will drift apart.

## Dependencies

Cross-stack dependencies are wired via `autoinclude { dependency ... }` blocks in `terragrunt.stack.hcl`, each with `mock_outputs` so `init`/`validate`/`plan` can run before the real state exists:

- `platform/compute`'s `aca_env` and `aks` units depend on `platform/rg`'s resource group output.
- `platform/workloads`'s `argocd` unit depends on `platform/compute`'s `aks` unit (cluster host/credentials).

Current live app stacks pass explicit values such as:

- `resource_group_name`
- `container_app_environment_name`
- `container_image`
- optional `ingress`
- optional `liveness_probes`, `readiness_probes`, and `startup_probes`
