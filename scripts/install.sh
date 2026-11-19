#!/usr/bin/env bash
# Deploy this repo's config onto the host. Idempotent; run as root from the repo.
set -euo pipefail
cd "$(dirname "$0")/.."
LIB=/usr/local/lib/vps-nginx

# Tailnet HTTPS port -> local nginx listener. Keep in sync with nginx/tailnet.conf.
declare -A SERVE_PORTS=(
  [443]=8080
)

# --- Clean up the old nginx-terminates-TLS setup (no-ops once gone) ---
if [[ -f /etc/systemd/system/tailscale-cert.timer ]]; then
  systemctl disable --now tailscale-cert.timer 2>/dev/null || true
  rm -f /etc/systemd/system/tailscale-cert.{service,timer}
fi
rm -rf "$LIB/scripts" /etc/nginx/tls
if [[ -f /etc/sysctl.d/99-vps-nginx.conf ]]; then
  rm -f /etc/sysctl.d/99-vps-nginx.conf
  sysctl -q -w net.ipv4.ip_nonlocal_bind=0 net.ipv6.ip_nonlocal_bind=0
fi

# --- Health-check service ---
install -D -m 644 healthcheck/server.py "$LIB/healthcheck/server.py"
install -m 644 systemd/healthcheck.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now healthcheck.service
systemctl restart healthcheck.service

# --- nginx ---
rm -f /etc/nginx/sites-enabled/default
install -D -m 644 nginx/tailnet.conf /etc/nginx/sites-available/tailnet.conf
ln -sf /etc/nginx/sites-available/tailnet.conf /etc/nginx/sites-enabled/tailnet.conf
nginx -t
systemctl reload-or-restart nginx

# --- tailscale serve (TLS termination; config persists in tailscaled) ---
for https_port in "${!SERVE_PORTS[@]}"; do
  tailscale serve --bg --https="$https_port" "http://127.0.0.1:${SERVE_PORTS[$https_port]}" >/dev/null
done
tailscale serve status

echo "Deployed. Test from a tailnet node: curl https://<host>.<tailnet>.ts.net/health"
