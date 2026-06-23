# Operations guide

Routine service checks, upgrades, backups, access procedures, and cost controls will be documented here as the platform becomes operational.

## Ubuntu host bootstrap

After Terraform creates the VM and SSH access is verified, the first operational task is to prepare the host.

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
- `/metrics` returns host metrics.
- Port `9100` is not open to the public internet.
