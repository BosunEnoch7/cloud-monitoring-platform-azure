# Monitoring documentation

Prometheus `3.12.0` and Node Exporter are installed and operational. Alert rules and dashboard interpretation will be added in the next phases.
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

## Prometheus scrape configuration

Prometheus scrapes two local targets every 15 seconds:

| Job | Target | Purpose |
|---|---|---|
| `prometheus` | `127.0.0.1:9090` | Prometheus runtime and self-monitoring |
| `node` | `127.0.0.1:9100` | Ubuntu host metrics |

The `up` query returned `1` for both targets after deployment. The active-target API also reported both targets as healthy with no scrape errors.

The 15-second interval balances useful dashboard and alert responsiveness against storage and CPU cost for this small development environment.

## Retention

Prometheus is configured with both retention limits:

- Time: 15 days
- Size: 10 GB

Prometheus applies whichever limit is reached first. This prevents unbounded local disk growth while retaining enough history for portfolio demonstrations and incident analysis.

## Network boundary

Prometheus and Node Exporter listen only on the VM loopback interface. They are not exposed through Azure NSG rules or UFW. Grafana will query Prometheus locally after it is installed.

## Grafana dashboard

Grafana `13.0.2` is provisioned from Git and queries the loopback Prometheus endpoint through its server-side proxy.

The `Cloud Monitoring - Node Overview` dashboard includes:

- current CPU usage
- current memory usage
- root filesystem usage
- system uptime
- CPU and memory trends
- 1-, 5-, and 15-minute system load
- network receive and transmit throughput
- filesystem usage by mount point

The dashboard refreshes every 30 seconds and defaults to a six-hour time range. Grafana's data-source health endpoint confirmed that it successfully queried the Prometheus API.
