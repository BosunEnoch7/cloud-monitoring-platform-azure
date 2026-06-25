# Cloud Monitoring Platform Azure

A production-inspired monitoring and observability platform built on Microsoft Azure with Terraform, Ubuntu Linux, Prometheus, Grafana, Alertmanager, and GitHub Actions.

The project is designed as a portfolio demonstration of infrastructure as code, Linux operations, monitoring, alerting, automation, security, and operational documentation. Azure is the first cloud implementation; the observability configuration and project vocabulary remain portable so that an AWS implementation can be added later.

## Project status

**Current phase:** Prometheus alert delivery to Alertmanager operational; email activation pending.

GitHub Actions deployed the Central US development environment through an OIDC-authenticated, plan-first workflow with a protected apply approval. Prometheus `3.12.0` evaluates tested alerts and sends them to Alertmanager `0.33.0`. All monitoring service endpoints are loopback-only. SMTP email routing awaits the operator's non-secret email details and separately supplied app password.

## Planned architecture

```text
Terraform
   |
   v
Azure infrastructure
   |
   v
Ubuntu VM
   |-- Node Exporter -- metrics --> Prometheus
   |                                  |
   |                                  |-- queries --> Grafana
   |                                  |
   |                                  `-- alerts --> Alertmanager --> Email
```

The initial implementation uses a single VM to control portfolio cost. This creates a known single point of failure and is not a highly available production topology. See [Architecture](docs/architecture.md) for the design, limitations, and evolution path.

## Repository layout

| Path | Purpose |
|---|---|
| `terraform/` | Reusable infrastructure modules and deployable environments |
| `prometheus/` | Scrape configuration and alert rules |
| `grafana/` | Provisioned data sources and dashboards |
| `alertmanager/` | Alert routing configuration templates |
| `scripts/` | Idempotent bootstrap and validation automation |
| `docs/` | Architecture, operations, troubleshooting, and learning records |
| `screenshots/` | Curated evidence of deployments, dashboards, and alerts |
| `.github/workflows/` | Terraform CI/CD workflows added in a later phase |

## Engineering principles

- Infrastructure changes are reviewed through Terraform plans.
- Secrets and Terraform state are never committed.
- Internal monitoring ports are not exposed publicly.
- Configuration is version-controlled and reproducible.
- Cost, security, failure modes, and operational tradeoffs are documented.
- Reusable components are separated from environment-specific composition.

## Roadmap

- [x] Define the architecture and repository boundaries
- [x] Implement and deploy Azure resources through Terraform
- [x] Bootstrap and harden the Ubuntu host
- [x] Install and validate Node Exporter
- [x] Configure Prometheus to scrape Node Exporter and itself
- [x] Add and unit-test host and monitoring availability alerts
- [x] Install Alertmanager and validate local alert delivery
- [ ] Provision Grafana dashboards
- [ ] Configure Alertmanager email routing
- [x] Add validation and protected deployment workflows in GitHub Actions
- [ ] Exercise failure scenarios and document incident response

## Documentation

- [Architecture](docs/architecture.md)
- [Documentation index](docs/README.md)
- [Incident and blocker log](docs/incidents.md)
- [Terraform structure](terraform/README.md)

## Licence

This project is available under the [MIT License](LICENSE).
