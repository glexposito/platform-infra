# Terragrunt Reference Architecture

This repository uses the Gruntwork "Live" Infrastructure Pattern (also known as the Terragrunt Reference Architecture) to manage Azure infrastructure deployments. 

This pattern relies on a strict directory hierarchy to keep configuration DRY (Don't Repeat Yourself), strictly limit the blast radius of changes, and provide a clear, discoverable map of your cloud environments.

## Directory Structure Hierarchy

The `live/` directory is organized into the following hierarchy:

```text
live/
└── [subscription] / [region] / [environment] / [service]
```

*   **Subscription (`live/non-prod/`, `live/prod/`):** Represents the Azure Subscription boundary. This provides the highest level of isolation for security and billing. Contains a `subscription.hcl` file.
*   **Region (`australiaeast/`):** Represents the physical Azure region where resources are deployed. Contains a `region.hcl` file.
*   **Environment (`dev/`, `stg/`, `prod/`):** The logical deployment stage. Contains an `env.hcl` file.
*   **Service (`status-page-updater/`):** The actual Terragrunt configuration (`terragrunt.hcl`) that calls a Terraform module to deploy a specific stack or application.

### Example Layout

```text
live/
├── non-prod/
│   ├── subscription.hcl         # Defines subscription_name = "non-prod"
│   └── australiaeast/
│       ├── region.hcl           # Defines location = "australiaeast"
│       ├── dev/
│       │   ├── env.hcl          # Defines environment = "dev"
│       │   └── status-page-updater/
│       │       └── terragrunt.hcl
│       └── stg/
│           ├── env.hcl          # Defines environment = "stg"
│           └── status-page-updater/
│               └── terragrunt.hcl
└── prod/
    ├── subscription.hcl         # Defines subscription_name = "prod"
    └── australiaeast/
        ├── region.hcl           # Defines location = "australiaeast"
        └── prod/
            ├── env.hcl          # Defines environment = "prod"
            └── status-page-updater/
                └── terragrunt.hcl
```

## How It Works

1.  **Isolated State Files:** Every leaf `terragrunt.hcl` file generates its own isolated Terraform state file in the Azure Storage backend based on its path (e.g., `non-prod/australiaeast/dev/status-page-updater/terraform.tfstate`). This physically limits the "blast radius"—a destructive command run in `dev` cannot corrupt the `prod` state file.
2.  **Inheritance (Future Phase):** This folder structure sets the foundation for hierarchical variable inheritance using Terragrunt's `read_terragrunt_config()` function. Eventually, leaf nodes won't need to define `location = "australiaeast"`; they will automatically inherit it from the `region.hcl` file above them.

---

## How to Extend the Architecture

The biggest advantage of this structure is how easy it is to scale. 

### Scenario: Adding a New Region (e.g., Singapore)

If you need to deploy the `prod` environment for the `status-page-updater` to a new region like Singapore (`southeastasia` in Azure), you simply replicate the folder structure.

**Step 1: Create the new region and environment directories.**
Navigate to the appropriate subscription (e.g., `prod`) and create the new region folder, followed by the environment folder.

```bash
mkdir -p live/prod/southeastasia/prod
```

**Step 2: Create the `region.hcl` file.**
Create the region variables file in the new region folder.

```bash
# live/prod/southeastasia/region.hcl
locals {
  location = "southeastasia"
}
```

**Step 3: Create the `env.hcl` file.**
Create the environment variables file.

```bash
# live/prod/southeastasia/prod/env.hcl
locals {
  environment = "prod"
}
```

**Step 4: Copy the service configuration.**
Copy the existing `status-page-updater` folder from the old region to the new region.

```bash
cp -r live/prod/australiaeast/prod/status-page-updater live/prod/southeastasia/prod/
```

**Step 5: Update the new `terragrunt.hcl` file.**
Edit `live/prod/southeastasia/prod/status-page-updater/terragrunt.hcl` to update any region-specific hardcoded values or names. 

For example, update resource names to reflect the new region:
```hcl
inputs = {
  location                       = "southeastasia" # Or use get_env / inherit
  resource_group_name            = "rg-spu-prod-sea"
  container_app_environment_name = "cae-spu-prod-sea"
  # ... other region-specific inputs
}
```

**Step 6: Deploy.**
Navigate to the new directory and apply. Terragrunt will automatically handle creating a brand new isolated state file for this Singapore deployment.

```bash
cd live/prod/southeastasia/prod/status-page-updater
terragrunt apply
```

Because of the folder isolation, this deployment is completely independent of the `australiaeast` deployment, ensuring high availability and fault tolerance.
