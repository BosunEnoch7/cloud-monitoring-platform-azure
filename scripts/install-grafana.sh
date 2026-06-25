#!/usr/bin/env bash
set -euo pipefail

GRAFANA_VERSION="13.0.2"
DATASOURCE_SOURCE="${1:-}"
DASHBOARD_PROVIDER_SOURCE="${2:-}"
DASHBOARDS_SOURCE="${3:-}"
ADMIN_CIDR="${4:-}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if [[ ! -f "${DATASOURCE_SOURCE}" || ! -f "${DASHBOARD_PROVIDER_SOURCE}" || ! -d "${DASHBOARDS_SOURCE}" ]]; then
  echo "Usage: sudo $0 datasource.yml dashboard-provider.yml dashboards-directory admin-cidr" >&2
  exit 1
fi

if [[ ! "${ADMIN_CIDR}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/32$ ]]; then
  echo "Admin access must be supplied as a single IPv4 /32 CIDR." >&2
  exit 1
fi

wait_for_url() {
  local url="$1"
  for ((attempt = 1; attempt <= 60; attempt++)); do
    if curl --fail --silent --show-error "${url}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Grafana health check failed: ${url}" >&2
  return 1
}

echo "==> Configuring the official Grafana package repository"
install -d -m 0755 /etc/apt/keyrings
curl --fail --silent --show-error --location https://apt.grafana.com/gpg.key |
  gpg --dearmor --yes --output /etc/apt/keyrings/grafana.gpg
chmod 0644 /etc/apt/keyrings/grafana.gpg
cat >/etc/apt/sources.list.d/grafana.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main
EOF

apt-get update -y
apt-get install -y "grafana=${GRAFANA_VERSION}"

echo "==> Provisioning Grafana from source control"
install -d -o root -g grafana -m 0750 /etc/grafana/provisioning/datasources
install -d -o root -g grafana -m 0750 /etc/grafana/provisioning/dashboards
install -d -o grafana -g grafana -m 0750 /var/lib/grafana/dashboards
install -o root -g grafana -m 0640 "${DATASOURCE_SOURCE}" /etc/grafana/provisioning/datasources/prometheus.yml
install -o root -g grafana -m 0640 "${DASHBOARD_PROVIDER_SOURCE}" /etc/grafana/provisioning/dashboards/default.yml
find /var/lib/grafana/dashboards -maxdepth 1 -type f -name '*.json' -delete
find "${DASHBOARDS_SOURCE}" -maxdepth 1 -type f -name '*.json' -exec install -o grafana -g grafana -m 0640 {} /var/lib/grafana/dashboards/ \;

if [[ ! -s /etc/grafana/admin_password ]]; then
  openssl rand -base64 32 >/etc/grafana/admin_password
  chown root:grafana /etc/grafana/admin_password
  chmod 0640 /etc/grafana/admin_password
fi

cat >/etc/grafana/grafana.ini <<'EOF'
[server]
http_addr = 0.0.0.0
http_port = 3000

[security]
admin_user = admin
admin_password = $__file{/etc/grafana/admin_password}
disable_gravatar = true
cookie_secure = false
cookie_samesite = strict

[users]
allow_sign_up = false

[auth.anonymous]
enabled = false

[analytics]
reporting_enabled = false
check_for_updates = false
EOF

echo "==> Restricting host firewall access to the administrator CIDR"
ufw delete allow from any to any port 3000 proto tcp >/dev/null 2>&1 || true
ufw allow from "${ADMIN_CIDR}" to any port 3000 proto tcp

echo "==> Starting Grafana"
systemctl daemon-reload
systemctl enable grafana-server
systemctl restart grafana-server
wait_for_url http://127.0.0.1:3000/api/health

echo "Grafana ${GRAFANA_VERSION} installation complete."
echo "The admin password is stored at /etc/grafana/admin_password (root:grafana, mode 0640)."
