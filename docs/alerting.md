# Alerting documentation

Prometheus evaluates five initial alert rules and sends firing alerts to Alertmanager `0.33.0` on `127.0.0.1:9093`.

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

## Alertmanager deployment

Alertmanager is installed as a dedicated non-login system user and managed by systemd. It is active, enabled at boot, and listens only on loopback.

Prometheus reports the following active Alertmanager endpoint:

```text
http://127.0.0.1:9093/api/v2/alerts
```

A synthetic `PortfolioPipelineTest` alert was injected with the official `amtool` client. Alertmanager reported it active with the expected labels and annotations. The same alert fingerprint was then updated with an expired end time, and `amtool` confirmed no matching active alert remained.

This proves local ingestion, grouping, receiver selection, and resolution. The temporary runtime receiver intentionally performs no external notification.

## Email activation status

The committed `alertmanager.yml.example` defines:

- grouped email notifications
- critical and warning repeat intervals
- resolved notifications
- warning inhibition when the matching critical alert exists

The active runtime configuration remains Git-ignored. Email activation requires:

- SMTP provider and host
- sender and recipient addresses
- SMTP username
- an application password or token supplied outside Git

The application password must never be posted in project documentation, committed, or embedded in the example file.
