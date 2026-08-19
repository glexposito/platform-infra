# Terraform And Terragrunt

This repo uses Terraform for Azure resources and Terragrunt for stack composition.

## Terraform

Terraform owns the actual infrastructure:

- [modules/resource-group](/home/guille/dev/platform-infra/modules/resource-group) creates the shared resource group
- [modules/aca-environment](/home/guille/dev/platform-infra/modules/aca-environment) creates the Log Analytics workspace and Container Apps environment
- [modules/aks-cluster](/home/guille/dev/platform-infra/modules/aks-cluster) creates the AKS cluster
- [modules/argocd](/home/guille/dev/platform-infra/modules/argocd) installs ArgoCD onto the AKS cluster
- [modules/aca-app](/home/guille/dev/platform-infra/modules/aca-app) creates one Container App with optional ingress, liveness/readiness/startup probes, secrets, and optional `AcrPull` role assignment
- [modules/aci-app](/home/guille/dev/platform-infra/modules/aci-app) creates one Azure Container Instance app
- [modules/storage-account](/home/guille/dev/platform-infra/modules/storage-account) creates a storage account

Remote state is configured from [root.hcl](/home/guille/dev/platform-infra/root.hcl).

## Terragrunt

Terragrunt handles:

- backend and provider generation
- per-stack inputs
- dependency wiring
- repeated wrappers under [units](/home/guille/dev/platform-infra/units)

Each stack root has a `terragrunt.stack.hcl`.

- `platform/rg`: `rg`
- `platform/compute`: `aca-env`, `aks-cluster`
- `platform/workloads`: `argocd`
- App stack: `aca-app`

## Ownership

Terraform remains the source of truth for:

- shared platform resources
- Container Apps
- scale settings
- ingress and probes
- environment variables and secrets
