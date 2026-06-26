# Prometheus

This area contains the Prometheus scrape configuration and version-controlled alert rules.

Prometheus scrapes:

- its own health and runtime metrics on `127.0.0.1:9090`
- Node Exporter host metrics on `127.0.0.1:9100`

Both endpoints are loopback-only. Grafana and Alertmanager run on the same host during the initial cost-controlled architecture.

The global scrape interval is 15 seconds. This gives responsive dashboards and alerts without producing unnecessary load for one development target.

Prometheus is installed from the pinned official release by:

```text
scripts/install-prometheus.sh
```

The installer verifies the official SHA-256 checksum, creates a dedicated service account, validates configuration with `promtool`, and deploys a hardened systemd service.
