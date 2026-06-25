#!/usr/bin/env bash
set -euo pipefail

# Bootstrap the Ubuntu monitoring host with the base operating-system packages
# and Node Exporter. This script is intentionally conservative: it prepares the
# host for observability without installing Prometheus, Grafana, or Alertmanager.

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root. Use: sudo ./scripts/bootstrap-monitoring-host.sh" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating package metadata"
apt-get update -y

echo "==> Installing baseline operations packages"
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  prometheus-node-exporter \
  ufw \
  unattended-upgrades

echo "==> Enabling unattended security updates"
systemctl enable --now unattended-upgrades

echo "==> Enabling Node Exporter"
cat >/etc/default/prometheus-node-exporter <<'EOF'
ARGS="--web.listen-address=127.0.0.1:9100"
EOF
systemctl enable --now prometheus-node-exporter
systemctl restart prometheus-node-exporter

echo "==> Configuring local firewall"
ufw allow OpenSSH
ufw --force enable

echo "==> Verifying Node Exporter health endpoint"
curl --fail --silent --show-error http://127.0.0.1:9100/metrics >/dev/null

echo "Bootstrap complete."
echo "Node Exporter is listening locally on port 9100."
