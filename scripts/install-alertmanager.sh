#!/usr/bin/env bash
set -euo pipefail

ALERTMANAGER_VERSION="0.33.0"
ALERTMANAGER_SHA256="8ce11c42e8a6dfbbf93a59c0b193cb1329210b36d0c7ef3df7b745608675a1d1"
ALERTMANAGER_ARCHIVE="alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz"
ALERTMANAGER_URL="https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/${ALERTMANAGER_ARCHIVE}"
CONFIG_SOURCE="${1:-}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if [[ -z "${CONFIG_SOURCE}" || ! -f "${CONFIG_SOURCE}" ]]; then
  echo "Usage: sudo $0 /path/to/rendered-alertmanager.yml" >&2
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

echo "==> Creating the Alertmanager service account and directories"
if ! getent group alertmanager >/dev/null; then
  groupadd --system alertmanager
fi

if ! id alertmanager >/dev/null 2>&1; then
  useradd \
    --system \
    --gid alertmanager \
    --home-dir /var/lib/alertmanager \
    --shell /usr/sbin/nologin \
    alertmanager
fi

install -d -o root -g alertmanager -m 0750 /etc/alertmanager
install -d -o alertmanager -g alertmanager -m 0750 /var/lib/alertmanager

installed_version=""
if [[ -x /usr/local/bin/alertmanager ]]; then
  installed_version="$(/usr/local/bin/alertmanager --version 2>&1 | sed -n 's/^alertmanager, version \([^ ]*\).*/\1/p')"
fi

if [[ "${installed_version}" == "${ALERTMANAGER_VERSION}" ]]; then
  echo "==> Alertmanager ${ALERTMANAGER_VERSION} is already installed"
else
  work_dir="$(mktemp -d)"
  trap 'rm -rf "${work_dir}"' EXIT

  echo "==> Downloading Alertmanager ${ALERTMANAGER_VERSION}"
  curl \
    --fail \
    --location \
    --proto '=https' \
    --tlsv1.2 \
    --output "${work_dir}/${ALERTMANAGER_ARCHIVE}" \
    "${ALERTMANAGER_URL}"

  echo "${ALERTMANAGER_SHA256}  ${work_dir}/${ALERTMANAGER_ARCHIVE}" | sha256sum --check

  tar -xzf "${work_dir}/${ALERTMANAGER_ARCHIVE}" -C "${work_dir}"
  release_dir="${work_dir}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64"

  echo "==> Installing versioned Alertmanager binaries"
  install -o root -g root -m 0755 "${release_dir}/alertmanager" /usr/local/bin/alertmanager
  install -o root -g root -m 0755 "${release_dir}/amtool" /usr/local/bin/amtool
fi

install -o root -g alertmanager -m 0640 "${CONFIG_SOURCE}" /etc/alertmanager/alertmanager.yml

echo "==> Validating Alertmanager configuration"
/usr/local/bin/amtool check-config /etc/alertmanager/alertmanager.yml

cat >/etc/systemd/system/alertmanager.service <<'EOF'
[Unit]
Description=Prometheus Alertmanager
Documentation=https://prometheus.io/docs/alerting/latest/alertmanager/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=alertmanager
Group=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager \
  --web.listen-address=127.0.0.1:9093
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ReadWritePaths=/var/lib/alertmanager
CapabilityBoundingSet=
AmbientCapabilities=

[Install]
WantedBy=multi-user.target
EOF

echo "==> Starting Alertmanager"
systemctl daemon-reload
systemctl enable alertmanager
systemctl restart alertmanager

echo "==> Verifying Alertmanager readiness"
wait_for_url http://127.0.0.1:9093/-/ready

echo "Alertmanager ${ALERTMANAGER_VERSION} installation complete."
