# Cloud Monitoring Platform Azure

A production-inspired monitoring and observability platform built on Microsoft Azure with Terraform, Ubuntu Linux, Prometheus, Grafana, Alertmanager, and GitHub Actions.

The project is designed as a portfolio demonstration of infrastructure as code, Linux operations, monitoring, alerting, automation, security, and operational documentation. Azure is the first cloud implementation; the observability configuration and project vocabulary remain portable so that an AWS implementation can be added later.

## Project status

**Current phase:** Azure infrastructure and GitHub Actions delivery path ready for first deployment.

The Terraform graph defines the resource group, network security boundary, public IP, NIC, and hardened Ubuntu monitoring VM. Remote state, OIDC identities, GitHub variables, protected deployment approval, and active workflows are configured. The workload infrastructure has not yet been applied.

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
- [ ] Implement Azure resources in the validated Terraform module contracts
- [ ] Bootstrap and harden the Ubuntu host
- [ ] Configure Node Exporter and Prometheus
- [ ] Provision Grafana dashboards
- [ ] Configure Alertmanager email routing
- [ ] Add validation and deployment workflows in GitHub Actions
- [ ] Exercise failure scenarios and document incident response

## Documentation

- [Architecture](docs/architecture.md)
- [Documentation index](docs/README.md)
- [Terraform structure](terraform/README.md)

## Licence

This project is available under the [MIT License](LICENSE).
