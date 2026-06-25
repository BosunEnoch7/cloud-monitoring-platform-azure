# Operations guide

Routine service checks, upgrades, backups, access procedures, and cost controls will be documented here as the platform becomes operational.

## Ubuntu host bootstrap

The Central US development VM was bootstrapped successfully on 2026-06-25 after Terraform deployment and SSH verification.

The bootstrap script is:

```text
scripts/bootstrap-monitoring-host.sh
```

It installs the baseline Linux operations packages, enables unattended security updates, enables Node Exporter, and verifies that the local metrics endpoint responds on port `9100`.

Node Exporter is intentionally not exposed publicly in the network security group. Prometheus will scrape it from the same host or from an approved private path, depending on the final topology.

## Initial service checks

After running the bootstrap script on the VM:

```bash
systemctl status prometheus-node-exporter
curl http://127.0.0.1:9100/metrics
```

Expected result:

- `prometheus-node-exporter` is active.
- `prometheus-node-exporter` is enabled at boot.
- `/metrics` returns host metrics.
- Port `9100` is not open to the public internet.

The verified host state is:

- Hostname: `monitoring`
- Node Exporter: active and enabled
- UFW: active, default-deny incoming
- Public host port: SSH only, additionally restricted by the Azure NSG

## Administrator IP rotation

SSH and Grafana access are restricted by Terraform to explicit administrator CIDRs. If the workstation public address changes:

1. Determine the new public IPv4 address.
2. Update `TF_ADMIN_SOURCE_CIDRS_JSON` in GitHub using valid JSON, for example `["203.0.113.10/32"]`.
3. Dispatch the Terraform Apply workflow with confirmation `deploy`.
4. Review the saved plan and approve the protected `dev` environment.
5. Retest SSH after the apply succeeds.

Never solve an address change by allowing `0.0.0.0/0` to SSH.
