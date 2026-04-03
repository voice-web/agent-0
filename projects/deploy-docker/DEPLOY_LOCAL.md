# Local Bring-Up (Reference)

This page documents the reference local workflow in this directory.

For common failures (Keycloak / HSTS in Chrome, stale containers, secrets, images), see **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**.

## What it does

Single entrypoint script:
- `up.sh <infra|application> 127.0.0.1`

The script is designed so you can:
1. Bring up **infra** first (Caddy + Keycloak + shared docker network).
2. Bring up **application** later (HTML + API stubs) assuming infra is already running.

## Commands

You can use either:
- Legacy: `./scripts/up.sh <infra|application> <127.0.0.1>`
- New: `./scripts/up.sh <127.0.0.1> <infra|application> [more...]`

### Bring up infra only

```bash
./scripts/up.sh infra 127.0.0.1
```

Expected:
- starts `caddy` and `keycloak`
- creates/uses docker network `wc-127-0-0-1-net`
- Caddy bind-mounts **`.generated/local-path-127/Caddyfile`** (created by `compile.py` on each `up.sh`)

### Bring up application only (infra must already be up)

```bash
./scripts/up.sh application 127.0.0.1
```

### Bring up infra + application (one command)

```bash
./scripts/up.sh 127.0.0.1 infra application
```

Expected:
- starts `default-html` and `default-api-json` (and other enabled app services)
- attaches them to the same docker network **`wc-127-0-0-1-net`**

## Service enable/disable flags (environment config)

Use **`deployments/local-path-127/config.json`** (`service_overrides`) to conditionally deploy logical services without removing them from the bundle.

Current supported flags:
- `service_overrides.default-html.enabled`
- `service_overrides.default-api-json.enabled`
- `service_overrides.globe-landing.enabled`

Example:

```json
{
  "service_overrides": {
    "default-html": { "enabled": true },
    "default-api-json": { "enabled": true },
    "globe-landing": { "enabled": true }
  }
}
```

Set `"enabled": false` to disable a service for this environment.

## Local routing contract (Caddyfile)

Caddy listens on port `80` and uses **path-based routing**:
- `http://127.0.0.1:80/api/*` -> `default-api-json`
- `http://127.0.0.1:80/auth/*` -> `keycloak`
- `http://127.0.0.1:80/ui/*` -> `globe-landing` (**only when enabled**)
- anything else (e.g. `http://127.0.0.1:80/`) -> `default-html`

## Defaults / environment variables

The script supports environment arguments: `127.0.0.1` (path-based routing on :80) and `oci-vm` (host-based routing on :80 and :443).

You can override these by exporting before running:
- `KEYCLOAK_ENV_FILE` (default: `~/.secrets/worldcliques/<environment>/keycloak.env`)
  - This file is loaded by docker compose via Keycloak `env_file`
  - Format (example):
    - `KEYCLOAK_ADMIN=admin`
    - `KEYCLOAK_ADMIN_PASSWORD=change-me`
- `GLOBE_LANDING_ASSETS` (default: your local `globe-landing/site/assets` path)

## Keycloak admin secret file (per environment)

The infra stack uses a Keycloak `env_file` for the admin username/password.

Create the file outside git at:

`~/.secrets/worldcliques/127.0.0.1/keycloak.env`

Example:

```bash
mkdir -p ~/.secrets/worldcliques/127.0.0.1
cat > ~/.secrets/worldcliques/127.0.0.1/keycloak.env <<'EOF'
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=change-me
EOF
```

If you want a different location, set `KEYCLOAK_ENV_FILE` before running `./scripts/up.sh infra ...`.

## oci-vm (Oracle VM / public DNS)

Deployment bundle: **`vm-host-oci`** (alias **`oci-vm`**). Same script shapes:

```bash
./scripts/up.sh oci-vm infra application
```

Secrets file (default):

`~/.secrets/worldcliques/oci-vm/keycloak.env`

Config and flags: **`deployments/vm-host-oci/config.json`** (`service_overrides`, optional **`routing.html_hosts`** merged over **`deployments/vm-host-oci/routing.json`**).

Generated artifacts (after compile / `up`): **`.generated/vm-host-oci/Caddyfile`**, **`.generated/vm-host-oci/edge/docker-compose.yml`**, **`.generated/vm-host-oci/app/docker-compose.yml`**, shared network **`wc-oci-vm-net`** (see `services.json` → `network_name`).

**Host routing (summary):** `api.worldcliques.org` → API JSON; `auth.worldcliques.org` → Keycloak. **Default HTML:** only **explicit** hostnames in **`routing.html_hosts`** (default **`worldcliques.org`**). When **`globe-landing`** is enabled in config, **`/login`** on those hosts is redirected to **`/login/`** and **`/login/*`** goes to globe-landing (prefix stripped). When disabled, **`/login`** is served by default-html like any other path.

**Keycloak public URL:** defaults to **`https://auth.worldcliques.org/auth`**. If you run **HTTP-only** or a different edge URL, set **`KEYCLOAK_PUBLIC_URL`** before compose (same value used for **`KC_HOSTNAME_URL`** and **`KC_HOSTNAME_ADMIN_URL`**), e.g. `export KEYCLOAK_PUBLIC_URL='http://auth.worldcliques.org/auth'`.

**DNS (typical):** create **`A`/`AAAA`** for each name Caddy serves: at minimum **`worldcliques.org`**, **`api`**, **`auth`**. Add more HTML vhosts (e.g. **`www.worldcliques.org`**) by listing them in **`deployments/vm-host-oci/config.json`** → **`routing.html_hosts`** so TLS is only requested for names you own in DNS. **TLS:** HTTP-01 needs resolvable names and reachable :80/:443. For testing without public DNS, set **`WC_CADDY_TLS=internal`** before `up.sh` so the generated Caddyfile uses **`tls internal`**.

Optional:

- **`WC_CADDY_ACME_EMAIL`** — embedded in the generated Caddyfile global block when set (ACME account email).

## Reference files (for review)

- **Sources:** `deployments/local-path-127/`, `deployments/vm-host-oci/`, `schemas/`
- **Compiler:** `scripts/compile.py`
- **Operators:** `scripts/up.sh`, `scripts/down.sh`, `scripts/update.sh`, `scripts/print_routes.py`
- **Outputs (local, not in git):** `.generated/<deployment_id>/` — `Caddyfile`, `edge/docker-compose.yml`, `app/docker-compose.yml`, `resolved.json`

## Bring down

Stop everything started for this environment.

### Bring down without removing named volumes

```bash
./scripts/down.sh 127.0.0.1
```

This uses `docker compose down --remove-orphans` for the infra and application compose files.

### Bring down and remove volumes (destructive)

```bash
./scripts/down.sh --volumes 127.0.0.1
```

This also removes named volumes like Caddy’s TLS/ACME storage and Keycloak persistence (depending on how those are configured).

## Update one service container

If you rebuilt an image (even with the same tag) and want to refresh a single running container:

```bash
./scripts/update.sh <infra|application> 127.0.0.1 <service>
```

Example:

```bash
./scripts/update.sh application 127.0.0.1 globe-landing
```

What this does:
- validates that the service exists in the selected manifest compose file
- runs `docker compose up -d --no-deps --force-recreate <service>`
- recreates only that one container, which picks up the rebuilt local image tag

