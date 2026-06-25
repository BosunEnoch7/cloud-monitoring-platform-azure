# Grafana

Grafana assets are provisioned from source control rather than created only through the web interface. This makes dashboards and data-source configuration reproducible and reviewable.

The initial dashboard covers CPU, memory, root filesystem, uptime, load, network throughput, and filesystem usage. Prometheus is provisioned as the default data source.
