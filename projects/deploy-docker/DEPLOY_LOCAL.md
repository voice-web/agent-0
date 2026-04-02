# Local Bring-Up (Reference)

This page documents the reference local workflow in this directory.

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
- creates/uses docker network `wc-127.0.0.1-net`
- Caddy uses `examples/routing/Caddyfile-127.0.0.1`

### Bring up application only (infra must already be up)

```bash
./scripts/up.sh application 127.0.0.1
```

### Bring up infra + application (one command)

```bash
./scripts/up.sh 127.0.0.1 infra application
```

Expected:
- starts `default-html` and `default-api-json`
- attaches them to the same docker network `wc-127.0.0.1-net`

## Local routing contract (Caddyfile)

Caddy listens on port `80` and uses **path-based routing**:
- `http://127.0.0.1:80/api/*` -> `default-api-json`
- `http://127.0.0.1:80/auth/*` -> `keycloak`
- anything else (e.g. `http://127.0.0.1:80/`) -> `default-html`

## Defaults / environment variables

The script currently supports environment argument only: `127.0.0.1`.

You can override these by exporting before running:
- `KEYCLOAK_ENV_FILE` (default: `~/.secrets/worldcliques/127.0.0.1/keycloak.env`)
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

## Reference files (for review)

Script:
- `scripts/up.sh`

Infra compose:
- `compose/infra-127.0.0.1.yml`

Application compose:
- `compose/application-127.0.0.1.yml`

Caddy local routing:
- `examples/routing/Caddyfile-127.0.0.1`

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

