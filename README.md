# vps-nginx

Tailnet-only HTTPS entrypoint for `<host>.<tailnet>.ts.net`.

```
tailnet ──HTTPS──▶ tailscaled :443 ──HTTP──▶ nginx 127.0.0.1:8080 ──▶ services on 127.0.0.1:<port>
                  (tailscale serve,          (routing by path)
                   TLS + certs)
```

- **`tailscale serve`** listens on the tailnet only. It terminates TLS with the `*.ts.net` cert and renews it automatically.
- **nginx** listens on loopback only and routes by path to services.
- **Services** each run their own HTTP server bound to `127.0.0.1`.

Nothing listens on the public interface.

## Layout

| Path | Installed to | Purpose |
|---|---|---|
| `nginx/tailnet.conf` | `/etc/nginx/sites-enabled/` | Routing: one `server` block per tailnet HTTPS port |
| `healthcheck/server.py` | `/usr/local/lib/vps-nginx/` | Stdlib-only health server on `127.0.0.1:8081` |
| `systemd/healthcheck.service` | `/etc/systemd/system/` | Runs the health server |
| `scripts/install.sh` | (run in place) | Deploys everything and sets the `tailscale serve` port mapping |

## Deploy

```sh
git pull && sudo ./scripts/install.sh
```

The script is idempotent. It removes nginx's default site and applies the `tailscale serve` mapping, which persists across reboots.

## Health check

From any tailnet node:

```sh
curl https://<host>.<tailnet>.ts.net/health
# {"status": "ok", "host": "...", "uptime_s": ..., "client": "100.x.y.z"}
```

## Adding a service

1. Bind the service to `127.0.0.1:<port>`.
2. Choose how to expose it:
   - **Under a path on :443:** add a `location` block to the `:8080` server in `nginx/tailnet.conf`. A trailing slash on `proxy_pass` strips the prefix. The app must support running under a base path if it emits absolute URLs.
   - **On its own tailnet port** (e.g. `:8443`, so Tailscale ACLs can restrict which devices reach it): add a new `server { listen 127.0.0.1:8443; ... }` block, and add `[8443]=8443` to `SERVE_PORTS` in `scripts/install.sh`.
3. Redeploy.

## Client identity

- tailscaled sets `X-Forwarded-For` to the caller's tailnet IP. A client-supplied value is not trusted; this was tested.
- nginx turns that into `$remote_addr`, so per-location `allow 100.x.y.z; deny all;` works.
- `Tailscale-User-Login` and `Tailscale-User-Name` are passed through to services. They identify the *user*, not the device, and are absent for tagged devices.
