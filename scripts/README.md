# Automation scripts

This area is reserved for small, focused automation such as host bootstrap and configuration validation.

Scripts must be idempotent, fail clearly, avoid embedded secrets, and be suitable for non-interactive execution.

## Azure control-plane bootstrap

`bootstrap-azure.ps1` creates the prerequisites that workload Terraform cannot create for itself:

- Azure Storage remote-state resource group, account, and container in `eastus`
- Blob versioning and 14-day blob/container soft delete
- Shared-key access disabled after container creation
- Separate Microsoft Entra applications for planning and applying
- GitHub OIDC federated credentials for pull requests, `main`, and the `dev` environment
- Read-only planning and deployment role assignments
- Required Azure resource-provider registrations

The script is designed to be rerun. It does not deploy the workload infrastructure.
