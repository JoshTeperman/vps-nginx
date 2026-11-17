# vps-nginx

Tailnet-only HTTPS reverse proxy for `<host>.<tailnet>.ts.net`.

nginx listens **only** on this node's Tailscale addresses (`100.113.18.9`, `fd7a:115c:a1e0::f52c:120a`) on port 443 and proxies to services bound to `127.0.0.1`.

## Layout

| Path | Installed to | Purpose |
|---|---|---|
| `nginx/tailnet.conf` | `/etc/nginx/sites-enabled/` | HTTPS server block and routes |
| `healthcheck/server.py` | `/usr/local/lib/vps-nginx/` | Stdlib-only health server on `127.0.0.1:8081` |
| `systemd/healthcheck.service` | `/etc/systemd/system/` | Runs the health server |
| `systemd/tailscale-cert.{service,timer}` | `/etc/systemd/system/` | Daily `tailscale cert` renewal and nginx reload |
| `scripts/renew-cert.sh` | `/usr/local/lib/vps-nginx/` | Fetches cert; self-signed fallback if Tailscale HTTPS is disabled |
| `sysctl/99-vps-nginx.conf` | `/etc/sysctl.d/` | `ip_nonlocal_bind` so nginx starts before `tailscale0` is up |

## Deploy

```sh
git pull && sudo ./scripts/install.sh
```

The script is idempotent. It also removes nginx's default site.

## Health check

From any tailnet node:

```sh
curl https://<host>.<tailnet>.ts.net/health
# {"status": "ok", "host": "...", "uptime_s": ..., "client": "100.x.y.z"}
```

Until HTTPS Certificates are enabled in the Tailscale admin console (DNS page), the cert is self-signed, so use `curl -k`. After enabling them, run `sudo systemctl start tailscale-cert.service` to swap in the real cert.

## Adding a service

Bind the service to `127.0.0.1:<port>`. Then add a `location` block to `nginx/tailnet.conf` and redeploy.
