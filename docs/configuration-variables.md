# Configuration Variables Guide

This document explains the core variables used in the `terragrunt.hcl` files for deploying the Status Page Updater infrastructure. 

Understanding these inputs is crucial for maintaining naming conventions and tagging standards across the Azure environment.

## Base Variables

### `name`
*   **Meaning:** The short, base identifier for the workload or application. 
*   **Current Value:** `"spu"` (Status Page Updater)
*   **Usage in Azure:** This variable is **not** used to name physical Azure resources directly. Instead, it is used strictly for **tagging**. Every resource created by the module will have the tag `app = spu` applied to it.
*   **Why:** This allows you to easily filter and group resources in the Azure Portal (especially in Cost Management) across multiple regions and environments, regardless of their complex physical names.

### `environment`
*   **Meaning:** The logical deployment stage.
*   **Examples:** `"dev"`, `"stg"`, `"prod"`
*   **Usage in Azure:** Inherited from the `env.hcl` file. It is used as a standard tag (`environment = prod`) and injected dynamically into resource names.

### `location`
*   **Meaning:** The physical Azure datacenter region.
*   **Examples:** `"australiaeast"`, `"southeastasia"`
*   **Usage in Azure:** Inherited from the `region.hcl` file. Determines where the resources are physically provisioned.

---

## Dynamic Naming Convention

To ensure consistency, physical resource names are constructed dynamically using the inherited `environment` and `location` variables.

The standard naming pattern is: `[resource_type_prefix] - spu - [environment] - [region_shortcode]`

We use a local block in `terragrunt.hcl` to convert the full Azure location name into a 3-letter shortcode:
*   `australiaeast` -> `aue`
*   `southeastasia` -> `sea`

### Resource Name Inputs

*   **`resource_group_name`**: Uses prefix `rg-` (e.g., `rg-spu-prod-aue`)
*   **`container_app_environment_name`**: Uses prefix `cae-` (e.g., `cae-spu-prod-aue`)
*   **`log_analytics_workspace_name`**: Uses prefix `law-` (e.g., `law-spu-prod-aue`)
*   **`container_app_name`**: Uses prefix `ca-` (e.g., `ca-spu-prod-aue`)

By strictly defining these names in the input block, we ensure that our infrastructure-as-code remains the absolute source of truth for our Azure naming topology.
