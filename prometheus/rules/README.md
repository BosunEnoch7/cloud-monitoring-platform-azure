# Alert rules

Prometheus alert rules are separated by concern:

- Host resource and availability alerts
- Monitoring-service health alerts

Rules include useful labels and annotations, sustained `for` durations to reduce noise, and `keep_firing_for` windows to reduce notification flapping.

Thresholds:

| Alert | Condition | Duration | Severity |
|---|---|---:|---|
| `HighCpuUsage` | CPU usage above 80% | 5 minutes | warning |
| `HighMemoryUsage` | Memory usage above 80% | 5 minutes | warning |
| `HighFilesystemUsage` | Writable filesystem usage above 85% | 10 minutes | critical |
| `NodeExporterDown` | Node Exporter scrape fails | 2 minutes | critical |
| `PrometheusSelfScrapeFailed` | Prometheus self-scrape fails | 2 minutes | critical |

Run the rule tests with:

```bash
promtool test rules prometheus/rules/tests/alert-rules.test.yml
```

The Prometheus self-scrape alert can detect an unhealthy metrics endpoint while the process still evaluates rules. It cannot report a completely stopped Prometheus process; that requires an independent external observer.
