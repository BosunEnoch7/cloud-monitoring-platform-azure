# Alerting documentation

Prometheus evaluates five initial alert rules. Alertmanager routing and email delivery are added in the next phase.

| Alert | Trigger | Waiting period | Severity |
|---|---|---:|---|
| `HighCpuUsage` | CPU usage above 80% | 5 minutes | warning |
| `HighMemoryUsage` | Memory usage above 80% | 5 minutes | warning |
| `HighFilesystemUsage` | Writable filesystem usage above 85% | 10 minutes | critical |
| `NodeExporterDown` | Node Exporter scrape fails | 2 minutes | critical |
| `PrometheusSelfScrapeFailed` | Prometheus self-scrape fails | 2 minutes | critical |

## Why alerts use waiting periods

A threshold breach is not immediately a notification-worthy incident. The `for` duration requires the condition to remain true, reducing alerts caused by short CPU bursts, scrape delays, or temporary filesystem activity.

`keep_firing_for` keeps a recently recovered alert active briefly. This reduces notification flapping when a metric oscillates around its threshold.

## Validation

The rules are tested with:

```bash
promtool test rules prometheus/rules/tests/alert-rules.test.yml
```

Tests cover:

- sustained threshold breaches
- healthy below-threshold conditions
- Node Exporter unavailability
- Prometheus self-scrape failure
- expected labels and annotations

After deployment, the Prometheus runtime API reported all five rules with `health: ok`.

## Prometheus availability limitation

`PrometheusSelfScrapeFailed` can detect an unhealthy self-metrics endpoint while Prometheus is still able to evaluate rules. It cannot notify when the Prometheus process or entire VM is completely unavailable. Reliable detection of that failure requires an independent observer outside this VM.

## Controlled incident exercise

A Node Exporter outage exercise was initiated by stopping the service. The later observation step was interrupted by administrator IP rotation and local connectivity timeouts. Azure Run Command restored Node Exporter and reported the service active.

The unit test proves the rule expression and two-minute transition mathematically. A complete live firing-and-recovery capture remains on the final incident-test checklist and will be repeated when Alertmanager is configured, so the same exercise also validates notification delivery.
