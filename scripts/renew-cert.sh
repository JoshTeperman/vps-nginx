#!/usr/bin/env bash
# Fetch the Tailscale cert for this node; reload nginx if it changed.
# If Tailscale HTTPS certs aren't enabled and no cert exists, create a self-signed placeholder.
set -euo pipefail
DOMAIN="<host>.<tailnet>.ts.net"
DIR=/etc/nginx/tls
CRT="$DIR/vps.crt" KEY="$DIR/vps.key"
mkdir -p "$DIR"; chmod 700 "$DIR"

before=$(sha256sum "$CRT" 2>/dev/null || true)
if tailscale cert --cert-file "$CRT.new" --key-file "$KEY.new" "$DOMAIN"; then
  mv "$CRT.new" "$CRT"; mv "$KEY.new" "$KEY"
elif [[ ! -f "$CRT" ]]; then
  echo "tailscale cert unavailable; generating self-signed placeholder" >&2
  openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN" -keyout "$KEY" -out "$CRT" 2>/dev/null
fi
rm -f "$CRT.new" "$KEY.new"
chmod 600 "$KEY"

if [[ "$before" != "$(sha256sum "$CRT")" ]] && systemctl is-active --quiet nginx; then
  nginx -t && systemctl reload nginx
fi
