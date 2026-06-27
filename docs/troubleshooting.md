# Troubleshooting guide

Symptoms, diagnostic commands, likely causes, and recovery steps will be recorded here as the platform is built and tested.

For larger issues that affect delivery or require a decision, see the [Incident and blocker log](incidents.md). Troubleshooting focuses on repeatable diagnostic steps; the incident log captures the timeline, impact, treatment, and lessons learned.

## SSH timeout

Likely cause: the administrator public IP changed and no longer matches the Azure NSG allowlist.

Checks:

```powershell
Invoke-RestMethod -Uri 'https://api.ipify.org'
gh variable get TF_ADMIN_SOURCE_CIDRS_JSON --repo BosunEnoch7/cloud-monitoring-platform-azure
```

Treatment:

1. Update `TF_ADMIN_SOURCE_CIDRS_JSON` to the current `/32`.
2. Run the protected Terraform apply workflow.
3. Approve the `dev` environment after reviewing the plan.

Do not open SSH to `0.0.0.0/0`.

## Grafana connection timeout

Likely causes:

- the administrator public IP no longer matches the Azure NSG allowlist
- UFW still contains an older source `/32`
- Grafana is not listening on port `3000`

Check the current address and Azure rule first:

```powershell
Invoke-RestMethod -Uri 'https://api.ipify.org?format=json'
az network nsg rule list `
  --resource-group cloud-monitoring-dev-centralus-rg `
  --nsg-name cloud-monitoring-dev-monitoring-nsg `
  -o table
```

After applying the NSG change through Terraform, check the host:

```bash
sudo ufw status numbered
sudo ss -lntp | grep ':3000'
curl -I http://127.0.0.1:3000/login
```

Replace only the stale Grafana rule; do not expose port `3000` globally. Verify both layers:

```powershell
Test-NetConnection 20.83.32.114 -Port 3000
Invoke-WebRequest http://20.83.32.114:3000/login -UseBasicParsing
```

## Prometheus target down

Checks:

```bash
systemctl status prometheus
systemctl status prometheus-node-exporter
curl http://127.0.0.1:9090/api/v1/targets
```

Treatment:

```bash
sudo systemctl restart prometheus-node-exporter
sudo systemctl restart prometheus
```

If rule files changed, verify that rules are loaded at runtime:

```bash
curl http://127.0.0.1:9090/api/v1/rules
```

## Alertmanager not receiving alerts

Checks:

```bash
systemctl status alertmanager
curl http://127.0.0.1:9093/-/ready
curl http://127.0.0.1:9090/api/v1/alertmanagers
amtool --alertmanager.url=http://127.0.0.1:9093 alert query
```

Treatment:

1. Confirm Prometheus has the `alerting.alertmanagers` block.
2. Confirm Alertmanager listens on `127.0.0.1:9093`.
3. Restart Prometheus after configuration changes.

## Grafana cannot query Prometheus

Checks:

```bash
systemctl status grafana-server
curl http://127.0.0.1:3000/api/health
```

Use the Grafana API with the local admin password:

```bash
password=$(sudo cat /etc/grafana/admin_password)
curl -u "admin:$password" http://127.0.0.1:3000/api/datasources/uid/prometheus/health
```

Treatment:

1. Confirm Prometheus is ready on `127.0.0.1:9090`.
2. Confirm the provisioned data source URL is `http://127.0.0.1:9090`.
3. Restart Grafana after provisioning changes.

## Observability CI failure

Checks:

```bash
promtool check config prometheus/prometheus.yml
promtool test rules prometheus/rules/tests/alert-rules.test.yml
amtool check-config alertmanager/alertmanager.yml.example
jq empty grafana/dashboards/node-overview.json
```

Common causes:

- invalid YAML or JSON
- alert labels that do not match unit-test expectations
- a validation command with the wrong exit-code behavior
