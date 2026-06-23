# Development environment

This directory is the deployable Terraform root for the first Azure environment. It configures the AzureRM provider, declares and validates environment inputs, establishes naming and tags, and will call reusable modules.

Real `.tfvars` files are ignored. Only a sanitized `terraform.tfvars.example` will be committed.

## Current contract

- Region: `eastus2`
- Availability zone: `1`
- Name prefix: `<project_name>-<environment>`
- Default prefix: `cloud-monitoring-dev`
- Default resource group: `cloud-monitoring-dev-eastus2-rg`
- Required owner, subscription ID, trusted administrator CIDR, and SSH public key
- Default VM size: `Standard_D2as_v5` (2 vCPU, 8 GiB RAM)
- Default OS disk: 64 GiB
- Default network: `10.20.0.0/16`
- Default monitoring subnet: `10.20.1.0/24`

The root creates a region-specific resource group and composes the network and compute modules. Monitoring software bootstrap is not yet included.

The resource group name includes the location suffix so a future region fallback does not try to recreate an Azure resource group in a different region with the same name.

`location` is validated to the approved region set so a mistaken variable override cannot split resources across unsupported regions. The default is `eastus2`, selected as a documented capacity fallback after repeated East US VM allocation failures. Administrative access rejects `0.0.0.0/0`.

## Local preparation

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Replace the subscription ID, owner, trusted public `/32`, and SSH public key.
3. Authenticate with Azure CLI when Azure access is needed in a later phase.

Do not commit `terraform.tfvars`, state, plans, or private keys.

## Backend status

The backend uses Azure Storage with Microsoft Entra authorization. Backend values are supplied by GitHub repository variables rather than hard-coded into Terraform. Workload deployment occurs through GitHub Actions, not from this directory.
