# Terragrunt Reference Architecture

This repository uses the Gruntwork "Live" Infrastructure Pattern (also known as the Terragrunt Reference Architecture) to manage Azure infrastructure deployments. 

> **Reference:** This approach is heavily inspired by the official Gruntwork examples, specifically the [terragrunt-infrastructure-live-stacks-example](https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example) repository.

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
    ├── australiaeast/
    │   ├── region.hcl           # Defines location = "australiaeast"
    │   └── prod/
    │       ├── env.hcl          # Defines environment = "prod"
    │       └── status-page-updater/
    │           └── terragrunt.hcl
    └── southeastasia/
        ├── region.hcl           # Defines location = "southeastasia"
        └── prod/
            ├── env.hcl          # Defines environment = "prod"
            └── status-page-updater/
                └── terragrunt.hcl

## How It Works

1.  **Isolated State Files:** Every leaf `terragrunt.hcl` file generates its own isolated Terraform state file in the Azure Storage backend based on its path (e.g., `non-prod/australiaeast/dev/status-page-updater/terraform.tfstate`). This physically limits the "blast radius"—a destructive command run in `dev` cannot corrupt the `prod` state file.
2.  **DRY Variable Inheritance:** Leaf configurations use Terragrunt's `read_terragrunt_config()` function to dynamically pull values from the `.hcl` files above them in the directory tree. This means `location` and `environment` never have to be hardcoded in the child modules, completely eliminating repetition and preventing copy-paste errors.

---

## How to Extend the Architecture

The biggest advantage of this structure is how easy it is to scale. 

### Scenario: Adding a New Region (e.g., Europe)

If you need to deploy the `prod` environment for the `status-page-updater` to a new region like Europe (`westeurope` in Azure), you simply replicate the folder structure.

**Step 1: Create the new region and environment directories.**
Navigate to the appropriate subscription (e.g., `prod`) and create the new region folder, followed by the environment folder.

```bash
mkdir -p live/prod/westeurope/prod
```

**Step 2: Create the `region.hcl` file.**
Create the region variables file in the new region folder.

```bash
# live/prod/westeurope/region.hcl
locals {
  location = "westeurope"
}
```

**Step 3: Create the `env.hcl` file.**
Create the environment variables file.

```bash
# live/prod/westeurope/prod/env.hcl
locals {
  environment = "prod"
}
```

**Step 4: Copy the service configuration.**
Copy the existing `status-page-updater` folder from the old region to the new region.

```bash
cp -r live/prod/australiaeast/prod/status-page-updater live/prod/westeurope/prod/
```

**Step 5: Ensure DRY Config is Intact.**
Because we use variable inheritance, you don't even need to modify the file. The `terragrunt.hcl` file will automatically adapt to the new region! (Note: ensure your `region_short` map inside `terragrunt.hcl` is updated to handle "westeurope").

```hcl
locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  # Ensure the shortcode logic handles your new region
  region_short = local.region_vars.locals.location == "westeurope" ? "euw" : "unknown"
  # ...
}
```

**Step 6: Deploy.**
Navigate to the new directory and apply. Terragrunt will automatically handle creating a brand new isolated state file for this Singapore deployment.

```bash
cd live/prod/southeastasia/prod/status-page-updater
terragrunt apply
```

Because of the folder isolation, this deployment is completely independent of the `australiaeast` deployment, ensuring high availability and fault tolerance.

---

## How to Decommission an Environment (or Region)

If you no longer need an environment (e.g., you are shutting down the Singapore deployment), **do not simply delete the folder from Git.** Doing so will create "orphaned" infrastructure in Azure that will continue to accrue costs because Terraform will lose the ability to manage or delete it.

To safely decommission an environment, follow this two-step process:

### Step 1: Destroy the infrastructure in Azure
Before removing any code, navigate into the specific leaf directory of the environment you want to remove and instruct Terragrunt to destroy the physical resources.

```bash
cd live/prod/southeastasia/prod/status-page-updater
terragrunt destroy
```
*Terragrunt will read the state file, determine exactly what resources exist in Azure, and safely delete them.*

### Step 2: Delete the code and update CI/CD
Only **after** `terragrunt destroy` has successfully completed and verified the resources are gone should you remove the configuration files.

1.  Delete the directory from your repository:
    ```bash
    rm -rf live/prod/southeastasia
    ```
2.  Update your CI/CD pipelines (e.g., `.github/workflows/*.yml`) to remove any references or matrix targets pointing to the deleted environment.
3.  Commit and push the changes.
