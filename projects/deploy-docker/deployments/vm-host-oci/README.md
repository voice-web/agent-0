# vm-host-oci

## default-html globe assets (image-baked vs host mount)

**Current:** `default-html` has **no** `globe_assets_bind` volume. Earth texture and icons come from the **`local/default-html`** image (`default-site/assets/`). No `GLOBE_LANDING_ASSETS` path is required on the VM for the main site globe.

**To switch back to host-mounted assets (live sync from a repo tree):**

1. In `services.json`, under the `default-html` application service, add again:
   ```json
   "volumes_spec": ["globe_assets_bind"],
   ```
2. On the machine where you run `compile.py`, set a **real host path** to `globe-landing/site/assets` (or equivalent), then compile and recreate the container:
   ```bash
   export GLOBE_LANDING_ASSETS=/path/on/vm/to/site/assets
   python3 scripts/compile.py vm-host-oci
   # redeploy default-html
   ```
3. That bind mount **replaces** `/srv/www/assets` in the container; the directory must include `earth-equirect.jpg` and any other files you expect.

Git history for `services.json` also preserves the previous line if you prefer `git checkout` / revert on that hunk.

## Keycloak and API (optional edge / app services)

**Current:** `keycloak` is **optional** in `services.json` and **disabled** in `config.json` (`service_overrides.keycloak.enabled: false`). `default-api-json` is **disabled** the same way. The generated Caddyfile omits `api.worldcliques.org` and `auth.worldcliques.org` blocks when those are off; edge compose is **caddy-only** (no `depends_on` keycloak).

**Re-enable later:** set `keycloak` and/or `default-api-json` to `{ "enabled": true }` in `config.json`, run `compile.py vm-host-oci`, recreate edge/app stacks. You will need a real Keycloak `KEYCLOAK_ENV_FILE` again when Keycloak is enabled (`up.sh` / `update.sh` enforce it only if `keycloak` appears in `resolved.json` → `edge_service_names`).
