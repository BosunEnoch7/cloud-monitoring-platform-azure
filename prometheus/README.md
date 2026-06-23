# Prometheus

This area will contain Prometheus scrape configuration and version-controlled alert rules.

Planned targets include Node Exporter and Prometheus itself. Host rules will cover CPU, memory, disk, filesystem, and exporter availability. Configuration validation will be automated before deployment.

The first target will be Node Exporter on the Ubuntu monitoring VM. We validate it locally before adding Prometheus scrape configuration so failures are easier to isolate.
