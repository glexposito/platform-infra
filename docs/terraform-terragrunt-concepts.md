# Terraform & Terragrunt Concepts in ACA-Infra

This document explains the foundational concepts of Terraform and Terragrunt as they are applied in this repository. Use this as a guide to understand how the infrastructure is structured and managed.

---

## 1. Terraform Basics

Terraform is an Infrastructure as Code (IaC) tool that allows you to define cloud resources in human-readable configuration files.

### Providers
Providers are plugins that Terraform uses to interact with cloud providers (like Azure, AWS, GCP).
- **In this project:** The `azurerm` provider is used to manage Azure resources. It is globally configured in the `root.hcl` file and generated into every stack's `provider.tf` file.

### Modules
Modules are containers for multiple resources that are used together. They allow you to package and reuse infrastructure.
- **`modules/aca-environment`**: Provisions the "foundation" (Resource Group, Log Analytics, Container App Environment).
- **`modules/aca-app`**: Provisions a specific Container App and its permissions (AcrPull).

### Resources
Resources are the most important element in the Terraform language. They describe one or more infrastructure objects.
- *Example:* `azurerm_container_app` in `modules/aca-app/main.tf` defines the actual container running in Azure.

### State
Terraform must store state about your managed infrastructure and configuration. This state is used by Terraform to map real-world resources to your configuration.
- **Remote State:** Instead of a local `terraform.tfstate` file, we store state in an **Azure Storage Account**. This allows multiple team members to work on the same infrastructure.

---

## 2. Terragrunt Concepts

Terragrunt is a thin wrapper that provides extra tools for keeping your configurations DRY (Don't Repeat Yourself), working with multiple Terraform modules, and managing remote state.

### DRY (Don't Repeat Yourself)
In standard Terraform, you often find yourself copy-pasting provider and backend configurations. Terragrunt eliminates this.
- **`root.hcl`**: Contains the "source of truth" for the Azure backend and provider. All other folders "include" this file.
- **`live/units/`**: Contains reusable Terragrunt unit wrappers. Instead of repeating module wiring, dependency blocks, and naming logic in every environment, each `terragrunt.stack.hcl` composes these shared units.

### Dependencies
Infrastructure often has a natural order. You can't deploy an app until the environment (the cluster) exists.
- **In this project:** `myapp` has a `dependency` block pointing to `app-env`.
- **Outputs to Inputs:** Terragrunt automatically takes the `outputs` from the `app-env` module and passes them as `inputs` to the `myapp` module (e.g., the `container_app_environment_id`).
- **Mock Outputs:** When the `app-env` hasn't been deployed yet (e.g., in a CI check), `myapp` uses `mock_outputs`. This allows commands like `terragrunt plan` to work even if the dependent infrastructure doesn't exist yet by providing temporary "fake" IDs.

### Remote State Management
Terragrunt automatically configures the remote state for each module based on its file path.
- If a generated unit ends up at `live/non-prod/westeurope/dev/myapp`, Terragrunt will automatically set the state key to `live/non-prod/westeurope/dev/myapp/terraform.tfstate`.

### Locals and Functions
Terragrunt uses HCL functions to dynamically determine values:
- `find_in_parent_folders()`: Automatically finds the `root.hcl` file.
- `read_terragrunt_config()`: Imports variables from other `.hcl` files such as `region.hcl`.
- `get_env()`: Fetches environment variables when needed by Terragrunt configuration.

---

## 3. How they work together in this Repo

The architecture follows a "Folder-based Hierarchy."

### The Hierarchy
The folder structure **is** the configuration. Instead of large variable files, we use small `.hcl` files at each level:
1.  **Backend Layer** (`live/non-prod/backend.hcl`): Defines the Terraform state backend coordinates for that top-level environment group.
2.  **Region Layer** (`live/non-prod/westeurope/region.hcl`): Defines the Azure `location`.
3.  **Environment Layer** (`live/non-prod/westeurope/dev/terragrunt.stack.hcl`): The environment entrypoint that composes deployable units and sets environment-specific overrides such as `environment = "dev"`.
4.  **Unit Layer** (`live/units/myapp/terragrunt.hcl`): The reusable Terragrunt wrapper that maps stack `values` into Terraform inputs and dependencies.

Terragrunt uses the environment stack to generate deployable units. Those units read `region.hcl` from their generated location and receive the environment name from stack values.
We separate the **Platform** from the **Application**:
- **Landlord (`app-env`)**: Responsible for the Resource Group and the Container App Environment. It "owns" the land.
- **Tenant (`myapp`)**: Responsible for the container image and settings. It "rents" space in the Landlord's environment.

### Deployment Flow
When you run `terragrunt stack generate` and `terragrunt run --all apply` from an environment root:
1.  Terragrunt reads the `terragrunt.stack.hcl`.
2.  It generates deployable unit directories such as `app-env/` and `myapp/`.
3.  Each generated unit includes `root.hcl` to set up the Azure backend and provider.
4.  Each generated unit resolves `dependencies` (for example, `myapp` fetching IDs from `app-env`).
5.  Terragrunt invokes the Terraform module defined by the unit wrapper under `modules/`.
6.  It runs `terraform apply` with the calculated `inputs`.
