# Local Bring-Up (Reference)

This page documents the reference local workflow in this directory.

For common failures (Keycloak / HSTS in Chrome, stale containers, secrets, images), see **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**.

## What it does

Scripts take a **deployment dirname**: the folder name under **`deployments/`** (e.g. **`local-path-127`**, **`local-ports-127`**, **`vm-host-oci`**). Add **`deployments/<new-name>/`** with the usual JSON files to support a new target—no alias tables in the shell scripts.

Single entrypoint:
- `./scripts/up.sh <deployment-dirname>` — infra + application
- `./scripts/up.sh infra <deployment-dirname>` / `application <deployment-dirname>` — staged bring-up

The script is designed so you can:
1. Bring up **infra** first (Caddy + Keycloak + shared docker network).
2. Bring up **application** later (HTML + API stubs) assuming infra is already running.

## Commands

Either order for infra/application:

- `./scripts/up.sh <deployment-dirname> [infra] [application] ...`
- `./scripts/up.sh infra|application <deployment-dirname>`

### Bring up infra only

```bash
./scripts/up.sh infra local-path-127
```

Expected:
- starts `caddy` and `keycloak`
- creates/uses docker network `wc-127-0-0-1-net`
- Caddy bind-mounts **`.generated/local-path-127/Caddyfile`** (created by `compile.py` on each `up.sh`)

### Bring up application only (infra must already be up)

```bash
./scripts/up.sh application local-path-127
```

### Bring up infra + application (one command)

```bash
./scripts/up.sh local-path-127
```

(or `./scripts/up.sh local-path-127 infra application`)

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

Set `"enabled": false` to disable a service, then re-run **`./scripts/up.sh local-path-127`** (compile runs on each `up.sh`).

## Local routing contract (Caddyfile)

### Path per listener (`local-path-127`)

Caddy listens on port `80` and uses **path-based routing**:
- `http://127.0.0.1:80/api/*` -> `default-api-json`
- `http://127.0.0.1:80/auth/*` -> `keycloak`
- `http://127.0.0.1:80/ui/*` -> `globe-landing` (**only when enabled**)
- anything else (e.g. `http://127.0.0.1:80/`) -> `default-html`

### One port per service (`local-ports-127`)

Bundle **`local-ports-127`** uses **`routing.mode`: `local_ports`**. Caddy exposes a dedicated port per backend (defaults below; override in **`routing.service_ports`**):

| Port | Service |
|------|---------|
| 8090 | Keycloak (`KC_HTTP_RELATIVE_PATH` is **`/`**; open `http://127.0.0.1:8090/`) |
| 8091 | `default-api-json` |
| 8092 | `default-html` |
| 8093 | `globe-landing` |

Bring up like any other bundle: **`./scripts/up.sh local-ports-127`**. Keycloak secrets resolve as in **[Keycloak env_file resolution](#keycloak-env_file-resolution)** (default path uses **`config.env_name`**; if that file is missing, the scripts may pick another `keycloak.env` under **`~/.secrets/worldcliques/*/`**).

## Defaults / environment variables

Bundles included here: **`local-path-127`** (paths on **`127.0.0.1:80`**), **`local-ports-127`** (ports **8090–8093**), and **`vm-host-oci`** (hostnames on :80 / :443). Secrets paths usually use **`env_name`** in each bundle’s **`config.json`** under **`~/.secrets/worldcliques/<env_name>/`**, with optional fallback (see below).

You can override these by exporting before running:
- `KEYCLOAK_ENV_FILE` — absolute path to the Keycloak `env_file`. If you **export** this variable, it **must** exist; there is no fallback. (Leave it **unset** to use automatic resolution.)
  - Format (example):
    - `KEYCLOAK_ADMIN=admin`
    - `KEYCLOAK_ADMIN_PASSWORD=change-me`
- `GLOBE_LANDING_ASSETS` (default: your local `globe-landing/site/assets` path)

### Keycloak env_file resolution

`up.sh`, `down.sh`, and `update.sh` set `KEYCLOAK_ENV_FILE` for compose unless you already exported it. Automatic resolution (via `scripts/resolve_keycloak_env.py`) uses, in order:

1. **`config.json` → `keycloak_env_file`** (optional): path to the file. `~` is expanded; a **relative** path is resolved from the **`deploy-docker`** project root (parent of `deployments/`). If set, the file **must** exist.
2. **`~/.secrets/worldcliques/<env_name>/keycloak.env`** where **`env_name`** comes from **`config.json`**.
3. **Fallback:** any existing **`~/.secrets/worldcliques/*/keycloak.env`**, preferring in order **`127.0.0.1`**, the bundle’s **`env_name`**, **`local-path-127`**, **`oci-vm`**, then remaining directories by name. When a fallback is used, a one-line notice is printed on stderr.

## Keycloak admin secret file (per environment)

The infra stack uses a Keycloak `env_file` for the admin username/password.

A typical location (matches **`local-path-127`**’s **`env_name`**) is:

`~/.secrets/worldcliques/127.0.0.1/keycloak.env`

Example:

```bash
mkdir -p ~/.secrets/worldcliques/127.0.0.1
cat > ~/.secrets/worldcliques/127.0.0.1/keycloak.env <<'EOF'
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=change-me
EOF
```

To force a specific file for all runs of a bundle, either set **`KEYCLOAK_ENV_FILE`** in the shell or add **`keycloak_env_file`** to that bundle’s **`config.json`**.

## Oracle VM / public DNS (`vm-host-oci`)

Deployment dirname: **`vm-host-oci`**. Same script shapes:

```bash
./scripts/up.sh vm-host-oci infra application
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

## Validate deployment (HTTP smoke)

After bring-up, **`scripts/validate_deployment.py`** requests each URL in **`resolved.json`** → **`test_routes`** and checks status/body (HTML vs JSON) by route label. **`--compile`** refreshes **`resolved.json`** first. **`--insecure`** skips TLS verification (e.g. **`vm-host-oci`** with internal certs). With **`--head`**, only status codes under **500** are verified (no body checks).

```bash
python3 scripts/validate_deployment.py local-ports-127
python3 scripts/validate_deployment.py local-path-127 --compile
python3 scripts/validate_deployment.py vm-host-oci --insecure
```

## Tools bundle (`local-tools-127`)

**`routing.mode`: `tools_standalone`** — no edge stack (no Caddy, no Keycloak). Compile emits only **`.generated/local-tools-127/app/docker-compose.yml`** with **`local/recon-lab`** on **`tool_port`** (default **8096**).

```bash
# Build image first (from docker-images/)
./scripts/build-local.sh internal/recon-lab

./scripts/up.sh local-tools-127 application
```

Open **`http://127.0.0.1:8096/`** for the web UI. Enter a target URL the container can reach:

- **`http://host.docker.internal:8092/`** — host-published **default-html** (requires **`host_gateway`: true**, the default)
- **`http://default-html:8080/`** — add **`wc-local-ports-127-net`** to **`attach_networks`** in **`deployments/local-tools-127/routing.json`** after **`local-ports-127`** infra+app is up (so the tool shares that network)

**`recon-lab`** accepts **any** **http** / **https** URL. Set **`RECON_TLS_INSECURE=1`** on the service to skip certificate verification (e.g. internal TLS).

## Reference files (for review)

- **Sources:** `deployments/local-path-127/`, `deployments/local-ports-127/`, `deployments/local-tools-127/`, `deployments/vm-host-oci/`, `schemas/`
- **Compiler:** `scripts/compile.py`
- **Operators:** `scripts/up.sh`, `scripts/down.sh`, `scripts/update.sh`, `scripts/print_routes.py`, `scripts/resolve_keycloak_env.py`, `scripts/validate_deployment.py`
- **Outputs (local, not in git):** `.generated/<sanitized deployment_id>/` — `Caddyfile`, `edge/docker-compose.yml`, `app/docker-compose.yml`, `resolved.json` (see **`deployment.json`** → **`deployment_id`**; usually matches the bundle dirname)

## Bring down

Stop everything started for this environment.

### Bring down without removing named volumes

```bash
./scripts/down.sh local-path-127
```

This uses `docker compose down --remove-orphans` for the infra and application compose files.

### Bring down and remove volumes (destructive)

```bash
./scripts/down.sh --volumes local-path-127
```

This also removes named volumes like Caddy’s TLS/ACME storage and Keycloak persistence (depending on how those are configured).

## Update one service container

If you rebuilt an image (even with the same tag) and want to refresh a single running container:

```bash
./scripts/update.sh <infra|application> <deployment-dirname> <service> [<image_tag_or_image>]
```

Example:

```bash
./scripts/update.sh application local-path-127 globe-landing
```

Try a different image tag **without** editing `services.json` (one-off compose override):

```bash
./scripts/update.sh application local-ports-127 default-html 0.0.6
# or full reference:
./scripts/update.sh application local-ports-127 default-html local/default-html:0.0.6
```

What this does:
- validates that the service exists in the selected manifest compose file
- optional 4th argument: temporary `image:` override merged for this `docker compose` run only (`services.json` and generated compose stay unchanged)
- runs `docker compose up -d --no-deps --force-recreate <service>`
- recreates only that one container, which picks up the rebuilt local image tag

