# compose/ — local bring-up examples

These compose files support the reference bring-up workflow:
- `up.sh infra 127.0.0.1` starts `caddy` + `keycloak` and creates a shared docker network.
- `up.sh application 127.0.0.1` starts enabled app services on the same network.
- `up.sh infra oci-vm` / `up.sh application oci-vm` use the same pattern on network `wc-oci-vm-net` with Caddy on **80 and 443**.

Request routing for local:
- `http://127.0.0.1/api/*` -> `default-api-json`
- `http://127.0.0.1/auth/*` -> `keycloak`
- `http://127.0.0.1/ui/*` -> `globe-landing` (when enabled in config)
- everything else -> `default-html`

Service enable flags come from:
- `../configs/127.0.0.1.json` or `../configs/oci-vm.json`

Keycloak admin credentials:
- The infra compose file reads Keycloak admin username/password from `env_file`
- Default paths: `~/.secrets/worldcliques/127.0.0.1/keycloak.env` or `~/.secrets/worldcliques/oci-vm/keycloak.env`

### oci-vm (host-based routing)

Caddy listens on **:80** and **:443** (automatic HTTPS for the public hostnames unless `WC_CADDY_TLS=internal` when generating the Caddyfile).

- `api.worldcliques.org` → `default-api-json`
- `auth.worldcliques.org` → `keycloak` (paths include `/auth` per `KC_HTTP_RELATIVE_PATH`)
- Explicit HTML hosts only (default **`worldcliques.org`**; set **`WC_OCI_HTML_HOSTS`** e.g. to `worldcliques.org, www.worldcliques.org` when you have DNS for each) → `default-html`
- **`/login/`** on those hosts → `globe-landing` (**when enabled**); **`/login`** redirects to **`/login/`** so assets load; prefix `/login` is stripped for the upstream
- Keycloak remains on `auth.worldcliques.org` (and `/auth` paths there)

Per-hostname HTTP-01 certs are the default (no `*.worldcliques.org` in Caddy). For a lab VM use `WC_CADDY_TLS=internal` and trust Caddy's local CA (or use `/etc/hosts` + browser exceptions).

