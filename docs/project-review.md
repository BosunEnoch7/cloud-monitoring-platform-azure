# Final project review

## Status

The Azure implementation is portfolio-ready as of 2026-06-26.

The deployed platform includes:

- Azure resource group, virtual network, subnet, NSG, public IP, NIC, and Ubuntu VM
- Terraform remote state in Azure Storage
- GitHub Actions OIDC plan/apply workflow with protected `dev` approval
- Ubuntu hardening with UFW and unattended upgrades
- Node Exporter host metrics
- Prometheus `3.12.0` scraping Node Exporter and itself
- Tested Prometheus alert rules
- Alertmanager `0.33.0` local alert delivery
- Grafana `13.0.2` with provisioned Prometheus data source and infrastructure dashboard
- Observability CI validation
- Incident, troubleshooting, and lessons-learned documentation

## Verified evidence

| Area | Evidence |
|---|---|
| Terraform deployment | GitHub Actions apply run `28044710581` succeeded |
| SSH CIDR rotation | GitHub Actions apply run `28167787774` succeeded |
| Observability CI | GitHub Actions run `28195186699` succeeded |
| Least-privilege verification | GitHub Actions apply run `28196178635` succeeded |
| Grafana | Dashboard `cloud-node-overview` loaded from provisioning |
| Alertmanager | Synthetic `PortfolioPipelineTest` alert was ingested and resolved |

Useful URLs:

- Repository: `https://github.com/BosunEnoch7/cloud-monitoring-platform-azure`
- Grafana: `http://20.83.32.114:3000`
- Observability CI: `https://github.com/BosunEnoch7/cloud-monitoring-platform-azure/actions/runs/28195186699`
- Least-privilege Terraform verification: `https://github.com/BosunEnoch7/cloud-monitoring-platform-azure/actions/runs/28196178635`

## Security posture

- SSH is restricted to the administrator `/32` in Azure NSG.
- Grafana is restricted to the administrator `/32` in both Azure NSG and UFW.
- Prometheus, Alertmanager, and Node Exporter are loopback-only.
- VM password authentication is disabled.
- Terraform state is remote and not committed.
- SMTP credentials are intentionally absent from Git.
- The GitHub apply identity no longer has subscription-wide Contributor.

Final apply identity permissions:

- `Contributor` on `cloud-monitoring-dev-centralus-rg`
- `Storage Blob Data Contributor` on the Terraform state storage account

## Known limitations

- Single-VM design is not highly available.
- Direct public-IP access remains a portfolio convenience.
- Grafana is HTTP-only for now.
- Prometheus cannot alert on its own total outage without an external observer.
- External SMTP delivery is an optional credential-dependent extension.

## Optional extension

To complete the email requirement, provide:

- SMTP provider
- sender email
- recipient email

Then create an app password or SMTP token outside Git and install the rendered runtime Alertmanager configuration.
