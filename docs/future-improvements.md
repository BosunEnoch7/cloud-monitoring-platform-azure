# Future improvements

Planned improvements include external uptime monitoring, higher availability, HTTPS ingress, private access, stronger secret management, backup testing, and an AWS implementation.

Additional implementation follow-ups:

- Add preflight Azure SKU and allocation-capacity guidance before deployment.
- Validate Terraform complex-type GitHub variables before workflow dispatch.
- Automate or document administrator `/32` rotation without widening access.
- Update pinned GitHub Actions releases that currently emit Node.js 20 deprecation warnings.
- Reduce the deployment identity from subscription-level bootstrap access to `Contributor` on `cloud-monitoring-dev-centralus-rg`.
