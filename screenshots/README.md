# Screenshots

This directory is reserved for curated visual evidence of the working platform.

## Recruiter evidence checklist

Capture these images in this order:

1. `01-azure-resource-group.png` — Azure resource group overview showing the deployed resource types.
2. `02-terraform-apply-success.png` — successful protected Terraform apply workflow.
3. `03-observability-ci-success.png` — successful observability validation workflow.
4. `04-prometheus-targets.png` — Prometheus targets showing `UP`.
5. `05-prometheus-alert-rules.png` — loaded CPU, memory, filesystem, and availability rules.
6. `06-alertmanager-pipeline.png` — Alertmanager status or the synthetic pipeline alert.
7. `07-grafana-node-overview.png` — the complete `Cloud Monitoring - Node Overview` dashboard.

The Grafana dashboard is the strongest portfolio image and should also appear near the top of the root README after it has been captured.

Email notification evidence is optional and should only be added after SMTP is activated.

## Capture quality

- Use PNG format at a readable desktop resolution.
- Capture the relevant application content rather than the entire desktop.
- Keep browser zoom and theme consistent.
- Prefer populated graphs covering at least the last 15 minutes.
- Do not stage an unhealthy system merely to make a screenshot dramatic.

## Security review

Before committing each image, inspect it for:

- subscription and tenant IDs
- public IP addresses
- email addresses
- usernames or local file paths
- tokens, secrets, app passwords, and QR codes
- unrelated browser tabs, notifications, or account details

Crop or redact sensitive fields before placing an image in this directory.
