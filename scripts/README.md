# Automation scripts

This area is reserved for small, focused automation such as host bootstrap and configuration validation.

Scripts must be idempotent, fail clearly, avoid embedded secrets, and be suitable for non-interactive execution.

## Azure control-plane bootstrap

`bootstrap-azure.ps1` creates the prerequisites that workload Terraform cannot create for itself:

- Azure Storage remote-state resource group, account, and container in `eastus`

## Host bootstrap

`bootstrap-monitoring-host.sh` prepares the Ubuntu monitoring VM after Terraform creates it.

It currently installs:

- baseline operations packages
- unattended security updates
- Node Exporter
- UFW with SSH allowed

The script does not install Prometheus, Grafana, or Alertmanager. Those services are added with separate, focused installers so each layer can be tested and documented independently.

Run from the VM after copying the repository or script:

```bash
sudo ./scripts/bootstrap-monitoring-host.sh
```

## Prometheus installation

`install-prometheus.sh` installs the pinned official Prometheus release, validates its checksum and configuration, and manages it with a hardened systemd unit.

Run it with the version-controlled configuration file:

```bash
sudo ./scripts/install-prometheus.sh ./prometheus/prometheus.yml
```
- Blob versioning and 14-day blob/container soft delete
- Shared-key access disabled after container creation
- Separate Microsoft Entra applications for planning and applying
- GitHub OIDC federated credentials for pull requests, `main`, and the `dev` environment
- Read-only planning and deployment role assignments
- Required Azure resource-provider registrations

The script is designed to be rerun. It does not deploy the workload infrastructure.
