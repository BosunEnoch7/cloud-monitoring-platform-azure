# Compute module

This module owns the Ubuntu virtual machine and directly related resources, including its network interface, public IP, OS disk, and managed identity.

The module boundary keeps compute lifecycle concerns separate from shared network policy. It accepts a subnet ID rather than depending directly on the network module, which keeps the module independently reusable.

## Resources and controls

- Standard, statically allocated public IPv4 address
- Network interface with a dynamically allocated private address
- Ubuntu 22.04 LTS Gen2 virtual machine
- Standard SSD OS disk
- SSH public-key authentication with passwords disabled
- Secure Boot and virtual TPM
- Azure platform patch assessment and patch installation
- Managed boot diagnostics
- System-assigned managed identity with no roles initially assigned

The public IP provides a straightforward portfolio access path, but the NSG restricts SSH and Grafana to trusted source CIDRs. A more mature design would use Azure Bastion, a VPN, private ingress, or a zero-trust access proxy.

The managed identity is created without permissions. Future access should add only the exact role assignments required instead of placing Azure credentials on the VM.

Monitoring software installation is intentionally absent. Host bootstrapping and service configuration will be implemented and tested as a separate concern.
