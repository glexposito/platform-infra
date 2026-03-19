# Terragrunt Reference Architecture

This repository uses the Gruntwork "Live" Infrastructure Pattern (also known as the Terragrunt Reference Architecture) to manage Azure infrastructure deployments. 

> **Reference:** This approach is heavily inspired by the official Gruntwork examples, specifically the [terragrunt-infrastructure-live-stacks-example](https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example) repository.

This pattern relies on a strict directory hierarchy to keep configuration DRY (Don't Repeat Yourself), strictly limit the blast radius of changes, and provide a clear, discoverable map of your cloud environments.

## Directory Structure Hierarchy

The `live/` directory is organized into the following hierarchy:

```text
live/
├── units/
│   ├── app-env/terragrunt.hcl
│   └── myapp/terragrunt.hcl
└── [environment-group] / [region] / [environment]
```

*   **Top-Level Environment Group (`live/non-prod/`, `live/prod/`):** Represents the highest isolation boundary in this repo. It contains a `backend.hcl` file with the Terraform state backend coordinates for that group.
*   **Region (`westeurope/`):** Represents the physical Azure region where resources are deployed. Contains a `region.hcl` file.
*   **Environment (`dev/`, `prod/`):** The logical deployment stage. Contains a `terragrunt.stack.hcl` entrypoint.
*   **Unit Definitions (`live/units/`):** Reusable Terragrunt unit wrappers that map stack `values` into Terraform module inputs and dependencies.

### Example Layout

```text
live/
├── units/
│   ├── app-env/
│   │   └── terragrunt.hcl      # Shared app environment unit wrapper
│   └── myapp/
│       └── terragrunt.hcl      # Shared app unit wrapper
├── non-prod/
│   ├── backend.hcl              # Defines state backend settings for non-prod
│   └── westeurope/
│       ├── region.hcl           # Defines location = "westeurope"
│       ├── dev/
│       │   └── terragrunt.stack.hcl
└── prod/
    ├── backend.hcl              # Defines state backend settings for prod
    ├── westeurope/
    │   ├── region.hcl           # Defines location = "westeurope"
    │   └── prod/
    │       └── terragrunt.stack.hcl
```

## How It Works

1.  **Isolated State Files:** Every generated unit still gets its own isolated Terraform state file in the Azure Storage backend based on its final path (for example `live/non-prod/westeurope/dev/myapp/terraform.tfstate`). This physically limits the blast radius: a destructive command run in `dev` cannot corrupt the `prod` state file.
2.  **Shared Unit Logic:** Environment-level `terragrunt.stack.hcl` files compose shared Terragrunt unit wrappers from `live/units/`. Those units read `region.hcl` from their generated location, while the environment name is passed explicitly from the stack file.
3.  **Platform vs. Application Separation (Landlord/Tenant Model):** We strictly separate the underlying shared environment from the applications that run on it.
    *   **The App Environment (`app-env`):** Acts as the "Landlord." It is deployed once per environment/region and provisions the shared foundation: the Resource Group, the Log Analytics Workspace, and the Container App Environment (the server cluster). In this repo, those resources currently use the shared stack token `platform-noncritical`.
    *   **The Application (`myapp`):** Acts as the "Tenant." It represents a single microservice. It uses a Terragrunt `dependency` block to ask the platform for its IDs, and then deploys a specific container image into that shared cluster. 
    
    *Example:* If you need to add a second microservice (e.g., `user-api`), you add another unit to the environment stack next to the others. It will automatically deploy into the existing `app-env`, significantly reducing Azure costs and simplifying architecture:

    ```text
    live/non-prod/westeurope/dev/
    └── terragrunt.stack.hcl     <-- Defines app-env, myapp, user-api units
    ```

---

## How to Extend the Architecture

The biggest advantage of this structure is how easy it is to scale. 

### Scenario: Adding a New Region (e.g., Europe)

If you need to deploy the `prod` environment for `myapp` to a new region beyond the current `westeurope` setup, you simply replicate the folder structure.

**Step 1: Create the new region and environment directories.**
Navigate to the appropriate subscription (e.g., `prod`) and create the new region folder, followed by the environment folder.

```bash
mkdir -p live/prod/northeurope/prod
```

**Step 2: Create the `region.hcl` file.**
Create the region variables file in the new region folder.

```bash
# live/prod/northeurope/region.hcl
locals {
  location = "northeurope"
}
```

**Step 3: Copy the environment stack file.**
Copy the existing stack file from the old region to the new region.

```bash
cp live/prod/westeurope/prod/terragrunt.stack.hcl live/prod/northeurope/prod/
```

**Step 4: Ensure the region short code exists.**
The naming logic depends on `location_short` from `region.hcl`, so add the right short code for the new region.

**Step 5: Deploy.**
Navigate to the new environment root and apply. Terragrunt will automatically handle both stacks and create isolated state files.

```bash
cd live/prod/northeurope/prod
terragrunt stack generate
terragrunt run --all --non-interactive init
terragrunt run --all --non-interactive apply -- -auto-approve -no-color
```

Because of the folder isolation, this deployment is completely independent of the `westeurope` deployment.

---

## How to Decommission an Environment (or Region)

If you no longer need an environment or region, **do not simply delete the folder from Git.** Doing so will create "orphaned" infrastructure in Azure that will continue to accrue costs because Terraform will lose the ability to manage or delete it.

To safely decommission an environment, follow this two-step process:

### Step 1: Destroy the infrastructure in Azure
Before removing any code, navigate into the specific environment root and instruct Terragrunt to destroy the physical resources.

```bash
cd live/prod/westeurope/prod
terragrunt run --all --non-interactive destroy -- -auto-approve -no-color
```
*Terragrunt will read the state file, determine exactly what resources exist in Azure, and safely delete them.*

### Step 2: Delete the code and update CI/CD
Only **after** `terragrunt destroy` has successfully completed and verified the resources are gone should you remove the configuration files.

1.  Delete the directory from your repository:
    ```bash
    rm -rf live/prod/westeurope
    ```
2.  Update your CI/CD pipelines (e.g., `.github/workflows/*.yml`) to remove any references or matrix targets pointing to the deleted environment.
3.  Commit and push the changes.

---

## Dependencies and Mock Outputs

Because the Application (`myapp`) depends on the App Environment (`app-env`), it uses a Terragrunt `dependency` block to fetch the necessary resource IDs.

Splitting modules into separate "stacks" (Platform vs Application) fundamentally changes how Terraform calculates its dependency graph. In a monolithic module, Terraform knows it will create all resources and can internally mark future IDs as `(known after apply)`. However, when separated, Terraform cannot natively read across different state files during a "Cold Start" (when the Platform hasn't been deployed yet).

If you attempt to run `terragrunt plan` on the Application during a cold start, Terraform will crash because it expects a cluster ID but receives null from the unapplied Platform state.

To solve this, the shared `myapp` unit wrapper under `live/units/myapp/terragrunt.hcl` uses Terragrunt `mock_outputs` for `init`, `validate`, `plan`, and `output`, but not for `apply`. It also uses `mock_outputs_merge_strategy_with_state = "shallow"` so partial state from a failed platform deployment can still be combined with mocks during non-apply commands.
