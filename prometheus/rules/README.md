# Alert rules

Prometheus alert rules will be separated by concern:

- Host resource and availability alerts
- Monitoring-service health alerts

Rules will include useful labels and annotations, a sustained `for` duration to reduce noise, and expressions that can be tested with `promtool`.
