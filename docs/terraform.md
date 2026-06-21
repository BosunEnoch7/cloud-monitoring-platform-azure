# Terraform design

## Root-module boundary

`terraform/environments/dev` is the only deployable root. Reusable components live under `terraform/modules` and must not own independent state.

The resource group is declared in the environment root because it is the lifecycle and governance boundary for the whole deployment. The network and compute modules receive its name explicitly.

## Current resource graph

```text
azurerm_resource_group.this
    |
    `-- module.network
          |-- azurerm_virtual_network.this
          |     `-- azurerm_subnet.monitoring
          |-- azurerm_network_security_group.monitoring
          |     |-- allow SSH from trusted CIDRs
          |     `-- allow Grafana from trusted CIDRs
          `-- subnet/NSG association
    |
    `-- module.compute
          |-- azurerm_public_ip.this
          |-- azurerm_network_interface.this
          `-- azurerm_linux_virtual_machine.this
                |-- SSH public key only
                |-- Standard SSD OS disk
                |-- managed boot diagnostics
                `-- system-assigned managed identity
```

Resource references establish dependency ordering. Explicit `depends_on` is unnecessary here because the module receives the resource-group attributes and its child resources reference their parent names and IDs.

## Inputs and validation

The root input model catches unsafe or malformed configuration before an Azure request is made:

- Azure subscription IDs must use UUID form.
- The project name is short, lowercase, and suitable for predictable resource naming.
- All resources are standardized in `eastus`.
- Network values must be valid IPv4 CIDRs.
- Administrative access cannot use `0.0.0.0/0`.
- SSH access accepts a public OpenSSH key, not a private key.
- OS disk size is bounded to prevent accidental extreme allocations.

Validation is a guardrail rather than a replacement for code review. For example, Terraform can prove that a CIDR is syntactically valid, but subnet containment and overlap still need deliberate design and later automated checks.

## Naming

The shared name prefix is:

```text
<project_name>-<environment>
```

The default is `cloud-monitoring-dev`. Azure resource-type suffixes will be added where resources are declared, such as `-rg`, `-vnet`, and `-vm`. The conceptual prefix remains cloud-neutral so an AWS implementation can use the same project identity with provider-appropriate resource names.

## Tags

Every supported resource will receive these mandatory tags:

- `project`
- `environment`
- `owner`
- `managed_by = terraform`

Environment-specific tags can be supplied with `additional_tags`. Mandatory tags are merged last, so custom input cannot overwrite governance values such as `owner` or `managed_by`.

## Provider and dependency lock

The code accepts compatible AzureRM 4.x releases. `.terraform.lock.hcl` records the exact version installed during initialization, protecting developers and CI from silently selecting different provider builds.

The provider receives only the subscription ID. Authentication remains outside source code.

## State

Backend configuration is isolated in `backend.tf` and now uses the bootstrapped Azure Storage account. Environment-specific backend values are injected by GitHub Actions rather than committed.

Remote state should provide:

- Encryption at rest
- Restricted access through Microsoft Entra ID
- Blob versioning and recovery protection
- State locking
- Separation between backend bootstrap and workload deployment

The supplied PowerShell bootstrap creates versioned storage with blob and container recovery retention, then disables shared-key access. GitHub authenticates to the backend through Microsoft Entra and OIDC.

## Validation performed

From the repository root:

```text
terraform fmt -check -recursive
```

From `terraform/environments/dev`:

```text
terraform init -backend=false
terraform validate
```

A real `terraform plan` now requires a populated `terraform.tfvars` and Azure authentication. `terraform apply` must not be run until the plan has been reviewed. No plan or apply was performed while defining the network graph.

The project deployment policy is stricter: local apply is not used. After remote state and workload identity are configured, GitHub Actions will own reviewed plans and protected applies. See [Terraform CI/CD design](ci-cd.md).
