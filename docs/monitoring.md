# Monitoring documentation

Metric sources, scrape behavior, recording strategy, retention, and dashboard interpretation will be documented here during the monitoring phase.
# Monitoring design

The first monitored target is the Ubuntu VM itself through Node Exporter.

Node Exporter exposes Linux host metrics such as:

- CPU time
- memory usage
- filesystem usage
- disk I/O
- network I/O
- system load
- boot time and uptime signals

The exporter listens on port `9100`. In this project, that port should not be exposed publicly. Prometheus will collect the metrics and Grafana will visualize them later.

## First validation target

Before installing Prometheus, validate Node Exporter directly on the VM:

```bash
curl http://127.0.0.1:9100/metrics
```

This confirms the operating-system metrics layer is working before we add the Prometheus scrape layer.
