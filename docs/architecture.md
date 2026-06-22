# Architecture

## Context

The platform demonstrates a complete infrastructure-monitoring workflow on Microsoft Azure while keeping the observability layer portable to another cloud provider.

## Initial deployment

```text
Operator
   |
   | Terraform
   v
Azure resource group
   |-- Virtual network and subnet
   |-- Network security group
   |-- Public IP and network interface
   `-- Ubuntu virtual machine
         |-- Node Exporter -- scraped by --> Prometheus
         |                                  |-- queried by --> Grafana
         |                                  `-- alerts to --> Alertmanager
         |                                                     |
         `-----------------------------------------------------`--> SMTP email
```

## Component responsibilities

- **Terraform** declares and reconciles Azure infrastructure.
- **Ubuntu Linux** provides the operating environment for monitoring services.
- **Node Exporter** exposes host and kernel metrics.
- **Prometheus** scrapes targets, stores time series, and evaluates alert rules.
- **Grafana** queries Prometheus and visualizes system behavior.
- **Alertmanager** groups, deduplicates, silences, and routes alerts.
- **GitHub Actions** will later validate and deliver infrastructure changes.

## Network policy

Only administrative access should cross the public boundary:

| Port | Service | Initial exposure |
|---:|---|---|
| 22 | SSH | Trusted administrator IP only |
| 3000 | Grafana | Trusted administrator IP only |
| 9090 | Prometheus | Private/loopback only |
| 9093 | Alertmanager | Private/loopback only |
| 9100 | Node Exporter | Private/loopback only |

Grafana should eventually be served through an authenticated HTTPS endpoint. Monitoring ports must not be opened broadly to the internet.

The NSG is associated with the monitoring subnet, making the subnet the baseline network-policy boundary. SSH and Grafana use separate rules so each access path can be reviewed, changed, or removed independently.

Azure's built-in NSG defaults deny unsolicited inbound internet traffic that is not explicitly allowed. We do not add redundant deny rules because they would add policy noise without strengthening the effective default behavior.

## Compute security

The monitoring host uses an Ubuntu LTS Gen2 image with password authentication disabled. Secure Boot and vTPM establish a stronger boot chain, while Azure-managed boot diagnostics avoids creating a separate diagnostics storage account.

A system-assigned managed identity is enabled but receives no role assignment by default. Identity existence does not grant access; permissions must be added separately through least-privilege role assignments.

The initial public IP is a cost-and-accessibility tradeoff for the portfolio environment. Source-restricted NSG rules reduce exposure, but a future production evolution should remove direct administrative ingress in favor of private access.

The VM and Standard public IP use an explicit East US availability zone. This avoids dependence on the constrained non-zonal allocation pool while keeping the entire environment in the required `eastus` region. A single zonal VM is still not highly available, and the selected zone may change when Azure reports live capacity restrictions.

## Key decisions

### Single VM for the first implementation

One VM keeps cost and operational scope appropriate for a portfolio environment. It also creates a shared failure domain: a VM outage removes collection, visualization, and alert delivery simultaneously.

This architecture is production-inspired, not highly available. The limitation will be made visible in documentation and failure testing.

### Pull-based metric collection

Prometheus scrapes Node Exporter. This provides centralized control of scrape intervals, target health through the `up` metric, and a clear inventory of monitored endpoints.

### Configuration as code

Dashboards, rules, data sources, and service configuration will live in Git. Manual UI changes that cannot be reproduced are not the source of truth.

### Cloud-neutral boundaries

Infrastructure implementation is necessarily Azure-specific, but modules use conceptual names such as `network` and `compute`. Prometheus rules and Grafana dashboards rely on standard exporter metrics rather than Azure-only metric names.

## Availability caveat

Prometheus cannot reliably announce its own total failure because a stopped process cannot evaluate an alert. A complete VM outage also removes Alertmanager.

An external observer is required for dependable end-to-end availability detection. Future options include Azure Monitor, an independent uptime service, or a second monitoring node.

## Evolution path

1. Deploy a reproducible, secured single-node development platform.
2. Add external availability monitoring and durable backups.
3. Separate monitoring components across failure domains.
4. Add TLS, stronger identity controls, and private administrative access.
5. Implement an AWS environment while reusing cloud-neutral observability assets.
