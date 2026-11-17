#!/usr/bin/env bash
# Deploy this repo's config onto the host. Idempotent; run as root from the repo.
set -euo pipefail
cd "$(dirname "$0")/.."
LIB=/usr/local/lib/vps-nginx

install -D -m 644 sysctl/99-vps-nginx.conf /etc/sysctl.d/99-vps-nginx.conf
sysctl -q --system

install -D -m 644 healthcheck/server.py "$LIB/healthcheck/server.py"
install -D -m 755 scripts/renew-cert.sh "$LIB/scripts/renew-cert.sh"
install -m 644 systemd/*.service systemd/*.timer /etc/systemd/system/
systemctl daemon-reload

"$LIB/scripts/renew-cert.sh"

rm -f /etc/nginx/sites-enabled/default
install -D -m 644 nginx/tailnet.conf /etc/nginx/sites-available/tailnet.conf
ln -sf /etc/nginx/sites-available/tailnet.conf /etc/nginx/sites-enabled/tailnet.conf
nginx -t

systemctl enable --now healthcheck.service tailscale-cert.timer
systemctl restart healthcheck.service
systemctl reload-or-restart nginx
echo "Deployed. Test from a tailnet node: curl https://<host>.<tailnet>.ts.net/health"
