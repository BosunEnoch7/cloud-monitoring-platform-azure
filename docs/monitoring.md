# Monitoring documentation

Node Exporter is now installed and validated. Scrape behavior, retention, rules, and dashboard interpretation will be added as Prometheus and Grafana are deployed.
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

## Node Exporter validation

Node Exporter was validated directly on the VM before installing Prometheus:

```bash
curl http://127.0.0.1:9100/metrics
```

The endpoint returned CPU, memory, filesystem, network, load, and boot-time series. This confirms the operating-system metrics layer is working before we add the Prometheus scrape layer.
