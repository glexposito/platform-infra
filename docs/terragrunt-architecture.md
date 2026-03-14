# Terragrunt Reference Architecture

This repository uses the Gruntwork "Live" Infrastructure Pattern (also known as the Terragrunt Reference Architecture) to manage Azure infrastructure deployments. 

> **Reference:** This approach is heavily inspired by the official Gruntwork examples, specifically the [terragrunt-infrastructure-live-stacks-example](https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example) repository.

This pattern relies on a strict directory hierarchy to keep configuration DRY (Don't Repeat Yourself), strictly limit the blast radius of changes, and provide a clear, discoverable map of your cloud environments.

## Directory Structure Hierarchy

The `live/` directory is organized into the following hierarchy:

```text
live/
├── _shared/
│   ├── env-platform.hcl
│   └── myapp.hcl
└── [subscription] / [region] / [environment] / [service]
```

*   **Subscription (`live/non-prod/`, `live/prod/`):** Represents the Azure Subscription boundary. This provides the highest level of isolation for security and billing. Contains a `subscription.hcl` file.
*   **Region (`australiaeast/`):** Represents the physical Azure region where resources are deployed. Contains a `region.hcl` file.
*   **Environment (`dev/`, `stg/`, `prod/`):** The logical deployment stage. Contains an `env.hcl` file.
*   **Service (`myapp/`, `env-platform/`):** The actual Terragrunt configuration (`terragrunt.hcl`) that includes shared stack logic and deploys a specific stack.
*   **Shared Config (`live/_shared/`):** Centralized Terragrunt config reused by many leaf stacks to remove copy-paste while preserving environment-specific behavior.

### Example Layout

```text
live/
├── _shared/
│   ├── env-platform.hcl        # Shared platform stack logic
│   └── myapp.hcl               # Shared app stack logic
├── non-prod/
│   ├── subscription.hcl         # Defines subscription_name = "non-prod"
│   └── australiaeast/
│       ├── region.hcl           # Defines location = "australiaeast"
│       ├── dev/
│       │   ├── env.hcl          # Defines environment = "dev"
│       │   ├── env-platform/
│       │   │   └── terragrunt.hcl
│       │   └── myapp/
│       │       └── terragrunt.hcl
│       └── stg/
│           ├── env.hcl          # Defines environment = "stg"
│           ├── env-platform/
│           │   └── terragrunt.hcl
│           └── myapp/
│               └── terragrunt.hcl
└── prod/
    ├── subscription.hcl         # Defines subscription_name = "prod"
    ├── australiaeast/
    │   ├── region.hcl           # Defines location = "australiaeast"
    │   └── prod/
    │       ├── env.hcl          # Defines environment = "prod"
    │       ├── env-platform/
    │       │   └── terragrunt.hcl
    │       └── myapp/
    │           └── terragrunt.hcl
    └── southeastasia/
        ├── region.hcl           # Defines location = "southeastasia"
        └── prod/
            ├── env.hcl          # Defines environment = "prod"
            ├── env-platform/
            │   └── terragrunt.hcl
            └── myapp/
                └── terragrunt.hcl
```

## How It Works

1.  **Isolated State Files:** Every leaf `terragrunt.hcl` file generates its own isolated Terraform state file in the Azure Storage backend based on its path (e.g., `live/non-prod/australiaeast/dev/myapp/terraform.tfstate`). This physically limits the blast radius: a destructive command run in `dev` cannot corrupt the `prod` state file.
2.  **DRY Variable Inheritance:** Shared stack configs use Terragrunt's `read_terragrunt_config()` function to dynamically pull values from the `.hcl` files above the active leaf directory. This means `location` and `environment` never have to be hardcoded in each child stack.
3.  **Platform vs. Application Separation (Landlord/Tenant Model):** We strictly separate the underlying platform from the applications that run on it.
    *   **The Platform (`env-platform`):** Acts as the "Landlord." It is deployed once per environment/region and provisions the shared foundation: the Resource Group, the Log Analytics Workspace, and the Container App Environment (the server cluster).
    *   **The Application (`myapp`):** Acts as the "Tenant." It represents a single microservice. It uses a Terragrunt `dependency` block to ask the platform for its IDs, and then deploys a specific container image into that shared cluster. 
    
    *Example:* If you need to add a second microservice (e.g., `user-api`), you simply add a new application folder next to the others. It will automatically deploy into the existing `env-platform`, significantly reducing Azure costs and simplifying architecture:

    ```text
    live/non-prod/australiaeast/dev/
    ├── env-platform/            <-- (Landlord: Provisions cluster once)
    ├── myapp/                   <-- (Tenant 1: myapp deploys into cluster)
    └── user-api/                <-- (Tenant 2: NEW! Deploys into cluster)
    ```

### Why `live/_shared` Works

The shared files are not generic templates with hardcoded paths. They resolve values relative to the real leaf stack Terragrunt is running.

For example, [myapp.hcl](/home/guille/dev/aca-infra/live/_shared/myapp.hcl) uses:

```hcl
region_vars = read_terragrunt_config("${get_original_terragrunt_dir()}/../../region.hcl")
env_vars    = read_terragrunt_config("${get_original_terragrunt_dir()}/../env.hcl")
```

`get_original_terragrunt_dir()` points to the leaf directory that included the shared file, not to `live/_shared`.

So if Terragrunt runs for:

```text
live/non-prod/australiaeast/dev/myapp
```

then the shared file resolves:

- `../../region.hcl` -> `live/non-prod/australiaeast/region.hcl`
- `../env.hcl` -> `live/non-prod/australiaeast/dev/env.hcl`

That is how the same shared config automatically receives:

- region: `australiaeast`
- environment: `dev`

without duplicating the whole `myapp` or `env-platform` config in every environment.

---

## How to Extend the Architecture

The biggest advantage of this structure is how easy it is to scale. 

### Scenario: Adding a New Region (e.g., Europe)

If you need to deploy the `prod` environment for `myapp` to a new region like Europe (`westeurope` in Azure), you simply replicate the folder structure.

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
Copy the existing stack folders from the old region to the new region.

```bash
cp -r live/prod/australiaeast/prod/env-platform live/prod/westeurope/prod/
cp -r live/prod/australiaeast/prod/myapp live/prod/westeurope/prod/
```

**Step 5: Ensure the region short code exists.**
The naming logic depends on `location_short` from `region.hcl`, so add the right short code for the new region.

**Step 6: Deploy.**
Navigate to the new environment root and apply. Terragrunt will automatically handle both stacks and create isolated state files.

```bash
cd live/prod/westeurope/prod
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

Because of the folder isolation, this deployment is completely independent of the `australiaeast` deployment.

---

## How to Decommission an Environment (or Region)

If you no longer need an environment (e.g., you are shutting down the Singapore deployment), **do not simply delete the folder from Git.** Doing so will create "orphaned" infrastructure in Azure that will continue to accrue costs because Terraform will lose the ability to manage or delete it.

To safely decommission an environment, follow this two-step process:

### Step 1: Destroy the infrastructure in Azure
Before removing any code, navigate into the specific environment root and instruct Terragrunt to destroy the physical resources.

```bash
cd live/prod/southeastasia/prod
terragrunt run --all --non-interactive destroy -- -auto-approve -no-color
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

---

## Dependencies and Mock Outputs

Because the Application (`myapp`) depends on the Platform (`env-platform`), it uses a Terragrunt `dependency` block to fetch the necessary resource IDs.

Splitting modules into separate "stacks" (Platform vs Application) fundamentally changes how Terraform calculates its dependency graph. In a monolithic module, Terraform knows it will create all resources and can internally mark future IDs as `(known after apply)`. However, when separated, Terraform cannot natively read across different state files during a "Cold Start" (when the Platform hasn't been deployed yet).

If you attempt to run `terragrunt plan` on the Application during a cold start, Terraform will crash because it expects a cluster ID but receives null from the unapplied Platform state.

To solve this, the shared `myapp` config uses Terragrunt `mock_outputs` for `init`, `validate`, `plan`, and `output`, but not for `apply`. It also uses `mock_outputs_merge_strategy_with_state = "shallow"` so partial state from a failed platform deployment can still be combined with mocks during non-apply commands.
