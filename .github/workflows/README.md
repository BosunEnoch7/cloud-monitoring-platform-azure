# Workflows

Terraform formatting, validation, planning, and controlled apply workflows are active.

- `terraform-plan.yml` validates and plans trusted pull requests.
- `terraform-apply.yml` creates a fresh saved plan from `main`, then pauses at the protected `dev` environment before applying it.
- `observability-validate.yml` validates shell automation, Prometheus configuration and rule tests, the Alertmanager template, Grafana dashboard JSON, and provisioning YAML.

Pull requests from public forks do not receive the Azure-backed plan job. This prevents untrusted fork code from obtaining an OIDC token with state access.

Observability validation requires no cloud credentials and is safe to run for pull requests. Prometheus and Alertmanager tooling runs from pinned official container image tags matching the deployed versions.
