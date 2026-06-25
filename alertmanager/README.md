# Alertmanager

This area contains a safe Alertmanager configuration template for email routing, grouping, inhibition, and resolved notifications.

Copy `alertmanager.yml.example` to the ignored `alertmanager.yml` file and replace the placeholders locally or directly on the VM.

The runtime configuration contains the SMTP application password, so it must never be committed. The installer deploys it with mode `0640`, owned by `root:alertmanager`.

Routing behavior:

- Alerts are grouped by alert name, environment, and instance.
- Alertmanager waits 30 seconds before the first grouped notification.
- Critical alerts repeat every hour.
- Warning alerts repeat every four hours.
- Resolved notifications are enabled.
- A critical version of the same alert inhibits its warning notification.

Alertmanager listens only on `127.0.0.1:9093`. Prometheus sends alerts locally.

Install a rendered configuration with:

```bash
sudo ./scripts/install-alertmanager.sh ./alertmanager/alertmanager.yml
```
