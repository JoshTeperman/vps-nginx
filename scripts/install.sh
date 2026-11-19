#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
LIB=/usr/local/lib/vps-nginx

declare -A SERVE_PORTS=(
  [443]=8080
)

install -D -m 644 healthcheck/server.py "$LIB/healthcheck/server.py"
install -m 644 systemd/healthcheck.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now healthcheck.service
systemctl restart healthcheck.service

rm -f /etc/nginx/sites-enabled/default
install -D -m 644 nginx/tailnet.conf /etc/nginx/sites-available/tailnet.conf
ln -sf /etc/nginx/sites-available/tailnet.conf /etc/nginx/sites-enabled/tailnet.conf
nginx -t
systemctl reload-or-restart nginx

for https_port in "${!SERVE_PORTS[@]}"; do
  tailscale serve --bg --https="$https_port" "http://127.0.0.1:${SERVE_PORTS[$https_port]}" >/dev/null
done
tailscale serve status

TS_HOST=$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')
echo "Deployed. Test from a tailnet node: curl https://$TS_HOST/health"
