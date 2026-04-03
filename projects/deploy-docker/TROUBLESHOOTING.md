# Troubleshooting (deploy-docker)

Operational notes for stacks brought up with `scripts/up.sh` and compiled bundles under `deployments/` / `.generated/`.

---

## Keycloak at `http://127.0.0.1/auth/` works in Incognito but not a normal Chrome window

**What you see:** Blank page, connection error, or the browser jumping to `https://127.0.0.1/...` even though Caddy only serves **HTTP** on port 80 locally.

**Why:** Keycloak (or something in the path) may have sent **`Strict-Transport-Security`** earlier. Chrome remembers that for the host (`127.0.0.1`) and **upgrades HTTP to HTTPS**. Incognito ignores that cached policy, so the same URL works there.

**What we did in this repo:** The generated Caddyfile strips `Strict-Transport-Security` on the Keycloak reverse proxy for **local path** routing, so **new** responses should not reinforce HSTS. Browsers can still have an **old** HSTS entry until you clear it.

### Clear HSTS for `127.0.0.1` (Chrome on macOS)

1. Open **`chrome://net-internals/#hsts`**
2. Under **Delete domain security policies**, enter **`127.0.0.1`**
3. Click **Delete**
4. If you also use **`localhost`**, repeat for that hostname
5. Reload **`http://127.0.0.1/auth/`** (a normal hard refresh is enough: **Cmd+Shift+R**)

**Note:** Clearing “Cached images and files” under Chrome’s normal clear-data UI does **not** remove HSTS; use **`chrome://net-internals/#hsts`** for that.

Other browsers store HSTS similarly (e.g. Firefox has `about:networking#dns` and internal tooling); the incognito-vs-normal symptom is the same pattern.

---

## After changing `deployments/` or `compile.py`, nothing seems updated

Bundles are **compiled on every `up.sh` run**. Containers still use old config until recreated when needed.

- Prefer a full infra cycle after editing edge services (Caddy, Keycloak):

  ```bash
  ./scripts/down.sh 127.0.0.1
  ./scripts/up.sh 127.0.0.1
  ```

- Or force recreate only the edge project (see `resolved.json` → `compose_projects.edge` and `paths.edge_compose`):

  ```bash
  docker compose -p wc-edge-127 -f .generated/local-path-127/edge/docker-compose.yml up -d --force-recreate
  ```

(Adjust `local-path-127` / project name for other deployments.)

---

## `Missing Keycloak env_file` or compose fails on secrets

`up.sh` expects a real file at **`KEYCLOAK_ENV_FILE`**, defaulting to `~/.secrets/worldcliques/<env_name>/keycloak.env` where `<env_name>` comes from that deployment’s `config.json`. Create the file with `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD` (see `DEPLOY_LOCAL.md`).

---

## `Missing` Docker images

`up.sh` checks images listed in `resolved.json` → `expected_images`. Build or load them from `projects/docker-images`, then rerun `up.sh`.

---

## Application stack says network not found

Bring up **infra** first so the shared Docker network exists, then **application**:

```bash
./scripts/up.sh infra 127.0.0.1
./scripts/up.sh application 127.0.0.1
```

The exact network name is in `.generated/<deployment>/resolved.json` → `network_name`.
