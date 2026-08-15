# Naming

## Azure resource names

Every resource name is built from the same four pieces: `<resource-prefix>-<name>-<environment>-<location>`.

| Piece | Where it comes from | Example |
|---|---|---|
| `<resource-prefix>` | Fixed per resource type (see table below) | `rg`, `aks`, `cae` |
| `<name>` | `values.name` in the owning `terragrunt.stack.hcl` unit block | `platform`, `pulse-api` |
| `<environment>` | `env.hcl` (`environment = "dev"`) | `dev` |
| `<location>` | `region.hcl` (`location_short = "sea"`) | `sea` |

Resource prefixes in use:

| Resource | Prefix | Example |
|---|---|---|
| Resource group | `rg` | `rg-platform-dev-sea` |
| AKS cluster | `aks` | `aks-platform-dev-sea` |
| Container Apps environment | `cae` | `cae-platform-dev-sea` |
| Log Analytics workspace | `law` | `law-platform-dev-sea` |
| Storage account | `st` | `stplatformdevsea` (no hyphens -- storage account names must be lowercase alphanumeric only) |
| Container App | `ca` | `ca-pulse-api-dev-sea` |

## Terraform state keys

State keys follow the same pieces as resource names, plus which specific unit within a stack:

```
platform/<environment>/<location>/<name>/<unit>/terraform.tfstate
```

`<unit>` is the unit's own leaf directory name (`rg`, `aca-env`, `aks`, `argocd`, ...) -- only that last path segment matters, not how deeply the unit is nested or which parent stack folder it sits under. This is intentional: state keys stay stable if you reorganize *where* a unit's config file lives, as long as its `values.name`, `env.hcl`, `region.hcl`, and leaf directory name don't change. Changing any of those four is a real identity change and does require a destroy-and-recreate, same as it would for the Azure resource name itself.

## Worked example: multiple environment tiers

`values.name` and `environment` are independent knobs -- combine them to reflect what's actually true, not folder position:

| Environment tier | `values.name` | Resulting AKS name |
|---|---|---|
| `dev` (internal use) | `platform-internal` | `aks-platform-internal-dev-sea` |
| `prod` | `platform` | `aks-platform-prod-sea` |

Note `prod` keeps `values.name = "platform"` rather than `"platform-prod"` -- `environment` already contributes `prod` to the name, so repeating it in `name` would produce `aks-platform-prod-prod-sea`. Only add a qualifier to `name` when it's actually distinguishing something `environment` doesn't already cover (here, `-internal` marks that `dev` is used for internal purposes, not just early-stage testing).

## Directory and unit naming

- Environment tiers: `live/<non-prod|prod>/<region>/<environment>/` -- e.g. `live/non-prod/southeastasia/dev/`.
- Stack folders: one per logical component group, e.g. `platform/` (shared cluster/platform resources), `pulse-api/` (one app).
- Unit block labels inside a `terragrunt.stack.hcl` should match their `path` value where possible (e.g. `unit "aca_env" { path = "aca-env" }`) -- labels use whatever casing Terragrunt requires for HCL identifiers (no hyphens), paths use kebab-case.
