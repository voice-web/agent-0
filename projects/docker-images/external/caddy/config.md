# caddy — deployment notes

Handoff for **docker compose** / ops. Image tag: **`local/caddy:<version.txt>`** (upstream Caddy version).

## Role

Path-based **ingress** / TLS termination. Usually the **only** service publishing **80/443** to the host; other services stay on the internal compose network.

## Ports

| Container | Typical publish |
|-----------|-----------------|
| **80** | HTTP (redirect to HTTPS in prod, or POC plain HTTP) |
| **443** | HTTPS when TLS enabled |

## Volumes / files

- **`Caddyfile`**: often mounted at **`/etc/caddy/Caddyfile`** so you can change routes without rebuilding. Default baked file in this image is a minimal POC only.
- **ACME / TLS storage**: if using automatic HTTPS, persist Caddy’s data dir (see [Caddy docs](https://caddyserver.com/docs/conventions#data-directory))—do not bake certs into the image.

## Environment

Usually none required for a static Caddyfile. **DNS / ACME** may need env if you template the file.

## Secrets (`~/.secrets` or env)

- TLS keys, ACME account material, or cloud DNS API tokens—**never** in the image; inject via compose **env_file** or **bind mounts** from **`~/.secrets`**.

## Compose hints

- Attach to a **user-defined network**; **`reverse_proxy`** upstreams use **service names** (e.g. **`http://open-webui:8080`**).
- From other containers, this service is typically **not** reached as `host.docker.internal`—only the **host** hits the published edge port.

## Health

- Add a **`respond /health`** block or use **`GET /`** if appropriate; wire **`healthcheck`** in compose.

## Upstream reference

- [Caddy](https://caddyserver.com/docs/)
