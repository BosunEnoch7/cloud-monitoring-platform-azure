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
