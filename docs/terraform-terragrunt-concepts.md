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
- **`_shared/`**: Contains common logic for a service (e.g., `myapp.hcl`). Instead of defining `myapp` in every environment folder, we define it once in `_shared` and reference it.

### Dependencies
Infrastructure often has a natural order. You can't deploy an app until the environment (the cluster) exists.
- **In this project:** `myapp` has a `dependency` block pointing to `app-env`.
- **Outputs to Inputs:** Terragrunt automatically takes the `outputs` from the `app-env` module and passes them as `inputs` to the `myapp` module (e.g., the `container_app_environment_id`).
- **Mock Outputs:** When the `app-env` hasn't been deployed yet (e.g., in a CI check), `myapp` uses `mock_outputs`. This allows commands like `terragrunt plan` to work even if the dependent infrastructure doesn't exist yet by providing temporary "fake" IDs.

### Remote State Management
Terragrunt automatically configures the remote state for each module based on its file path.
- If you are in `live/non-prod/australiaeast/dev/myapp`, Terragrunt will automatically set the state key to `live/non-prod/australiaeast/dev/myapp/terraform.tfstate`.

### Locals and Functions
Terragrunt uses HCL functions to dynamically determine values:
- `find_in_parent_folders()`: Automatically finds the `root.hcl` file.
- `read_terragrunt_config()`: Imports variables from other `.hcl` files (like `region.hcl` or `env.hcl`).
- `get_env()`: Fetches environment variables (like `AZURE_SUBSCRIPTION_ID`).

---

## 3. How they work together in this Repo

The architecture follows a "Folder-based Hierarchy."

### The Hierarchy
The folder structure **is** the configuration. Instead of large variable files, we use small `.hcl` files at each level:
1.  **Subscription Layer** (`live/non-prod/subscription.hcl`): Defines the Azure billing boundary.
2.  **Region Layer** (`live/non-prod/australiaeast/region.hcl`): Defines the Azure `location`.
3.  **Environment Layer** (`live/non-prod/australiaeast/dev/env.hcl`): Defines the `environment` name (dev, stg, prod).
4.  **Service Layer** (`live/non-prod/australiaeast/dev/myapp/terragrunt.hcl`): The final "leaf" that triggers the deployment.

Terragrunt crawls **up** from the leaf directory to collect all these variables and pass them into the Terraform module.
We separate the **Platform** from the **Application**:
- **Landlord (`app-env`)**: Responsible for the Resource Group and the Container App Environment. It "owns" the land.
- **Tenant (`myapp`)**: Responsible for the container image and settings. It "rents" space in the Landlord's environment.

### Deployment Flow
When you run `terragrunt apply` in a leaf directory:
1.  Terragrunt reads the `terragrunt.hcl`.
2.  It includes the `root.hcl` to setup the Azure Backend and Provider.
3.  It includes the `_shared/` logic to find the Terraform source code (`modules/`).
4.  It resolves `dependencies` (fetching IDs from the Landlord).
5.  It downloads the Terraform module.
6.  It runs `terraform apply` with the calculated `inputs`.
