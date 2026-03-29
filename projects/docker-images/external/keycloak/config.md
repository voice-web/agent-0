# keycloak — deployment notes

Handoff for **docker compose** / ops. Image tag: **`local/keycloak:<version.txt>`** (upstream Keycloak version).

## Role

Identity / OIDC provider. Often placed **behind Caddy** on a path (e.g. **`/auth/`**) or on its own hostname.

## Ports

| Container | Notes |
|-----------|--------|
| **8080** | Default HTTP (Keycloak “http” port in dev images; confirm for your tag) |

Adjust if you customize **`KC_HOSTNAME`** / proxy mode.

## Environment (common)

| Variable | Purpose |
|----------|---------|
| **`KEYCLOAK_ADMIN`** | Admin username (dev / bootstrap) |
| **`KEYCLOAK_ADMIN_PASSWORD`** | From **`~/.secrets`** or env—never commit |
| **`KC_HTTP_RELATIVE_PATH`** | If served under a subpath (e.g. **`/auth`**) behind reverse proxy |
| **`KC_PROXY`** / **`KC_HOSTNAME`** | When behind Caddy; set **X-Forwarded-*** correctly on the proxy |

**Dev POC:** often **`start-dev`** (ephemeral DB). **Production:** **`start`** + external **PostgreSQL** (separate service); see Keycloak docs for **`KC_DB_*`**.

## Volumes

- **Production:** persist realm state via DB, not container filesystem alone.
- Optional: **`COPY`** realm JSON in a custom image or mount imports—document in your compose project.

## Secrets (`~/.secrets` or env)

- Admin password, DB passwords, client secrets—**compose `env_file`** pointing at **`~/.secrets/...`**.

## Compose hints

- Caddy (or ingress) must send **`X-Forwarded-Proto`**, **`Host`**, and often **`X-Forwarded-For`**.
- Path-based hosting is **finicky**; hostname-based routing is often simpler for Keycloak.

## Health

- Use Keycloak health endpoint for your version (path varies); add **`healthcheck`** in compose once verified.

## Upstream reference

- [Keycloak server guides](https://www.keycloak.org/guides#server)
