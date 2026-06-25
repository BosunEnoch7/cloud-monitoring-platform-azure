#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_VERSION="3.12.0"
PROMETHEUS_SHA256="20da47f8e5303f74aecb78edd7f7e39041dac08ac4939dba75efd7a900ae8867"
PROMETHEUS_ARCHIVE="prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
PROMETHEUS_URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${PROMETHEUS_ARCHIVE}"
CONFIG_SOURCE="${1:-}"
RULES_SOURCE="${2:-}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if [[ -z "${CONFIG_SOURCE}" || ! -f "${CONFIG_SOURCE}" || -z "${RULES_SOURCE}" || ! -d "${RULES_SOURCE}" ]]; then
  echo "Usage: sudo $0 /path/to/prometheus.yml /path/to/rules-directory" >&2
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "This installer currently supports x86_64 hosts only." >&2
  exit 1
fi

wait_for_url() {
  local url="$1"
  local attempts=30

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if curl --fail --silent --show-error "${url}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "Health check failed after ${attempts} seconds: ${url}" >&2
  return 1
}

echo "==> Creating the Prometheus service account and directories"
if ! getent group prometheus >/dev/null; then
  groupadd --system prometheus
fi

if ! id prometheus >/dev/null 2>&1; then
  useradd \
    --system \
    --gid prometheus \
    --home-dir /var/lib/prometheus \
    --shell /usr/sbin/nologin \
    prometheus
fi

install -d -o root -g prometheus -m 0750 /etc/prometheus
install -d -o root -g prometheus -m 0750 /etc/prometheus/rules
install -d -o prometheus -g prometheus -m 0750 /var/lib/prometheus

installed_version=""
if [[ -x /usr/local/bin/prometheus ]]; then
  installed_version="$(/usr/local/bin/prometheus --version 2>&1 | sed -n 's/^prometheus, version \([^ ]*\).*/\1/p')"
fi

if [[ "${installed_version}" == "${PROMETHEUS_VERSION}" ]]; then
  echo "==> Prometheus ${PROMETHEUS_VERSION} is already installed"
else
  work_dir="$(mktemp -d)"
  trap 'rm -rf "${work_dir}"' EXIT

  echo "==> Downloading Prometheus ${PROMETHEUS_VERSION}"
  curl \
    --fail \
    --location \
    --proto '=https' \
    --tlsv1.2 \
    --output "${work_dir}/${PROMETHEUS_ARCHIVE}" \
    "${PROMETHEUS_URL}"

  echo "${PROMETHEUS_SHA256}  ${work_dir}/${PROMETHEUS_ARCHIVE}" | sha256sum --check

  tar -xzf "${work_dir}/${PROMETHEUS_ARCHIVE}" -C "${work_dir}"
  release_dir="${work_dir}/prometheus-${PROMETHEUS_VERSION}.linux-amd64"

  echo "==> Installing versioned Prometheus binaries"
  install -o root -g root -m 0755 "${release_dir}/prometheus" /usr/local/bin/prometheus
  install -o root -g root -m 0755 "${release_dir}/promtool" /usr/local/bin/promtool
fi

install -o root -g prometheus -m 0640 "${CONFIG_SOURCE}" /etc/prometheus/prometheus.yml
find /etc/prometheus/rules -maxdepth 1 -type f -name '*.yml' -delete
find "${RULES_SOURCE}" -maxdepth 1 -type f -name '*.yml' -exec install -o root -g prometheus -m 0640 {} /etc/prometheus/rules/ \;

echo "==> Restricting Node Exporter to the local host"
cat >/etc/default/prometheus-node-exporter <<'EOF'
ARGS="--web.listen-address=127.0.0.1:9100"
EOF

cat >/etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus monitoring and time-series database
Documentation=https://prometheus.io/docs/
Wants=network-online.target
After=network-online.target prometheus-node-exporter.service

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d \
  --storage.tsdb.retention.size=10GB \
  --web.listen-address=127.0.0.1:9090
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ReadWritePaths=/var/lib/prometheus
CapabilityBoundingSet=
AmbientCapabilities=

[Install]
WantedBy=multi-user.target
EOF

echo "==> Validating Prometheus configuration"
/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

echo "==> Starting Node Exporter and Prometheus"
systemctl daemon-reload
systemctl enable --now prometheus-node-exporter
systemctl restart prometheus-node-exporter
systemctl enable prometheus
systemctl restart prometheus

echo "==> Verifying local health endpoints"
wait_for_url http://127.0.0.1:9100/metrics
wait_for_url http://127.0.0.1:9090/-/ready

echo "Prometheus ${PROMETHEUS_VERSION} installation complete."
