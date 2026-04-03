# deploy-docker (reference)

This directory is a **reference implementation** (docs + deployment bundles + compiler) for how to separate deployment concerns over time:

- logical services (what you want to run)
- environment-specific config (how you want to run it)
- ingress/routing (how requests get to those services)
- secrets (never committed)
- renderer (produces `docker-compose.yml` or later K8s manifests)

The goal is to let you review the “model” first, then implement it in code inside `agent-0/projects/deploy/` (or a successor project).

## Layers (separation)

1. **Images**: pinned image names + versions/digests (built elsewhere, e.g. `projects/docker-images`).
2. **Logical services**: named capabilities you want to deploy (e.g. `default-html`, `default-api-json`, `caddy`, `keycloak`).
3. **Ingress / routing contract**: host/path/WebSocket behavior that routes requests to logical services.
4. **Service config overlay**: per environment parameters (env vars, mounts, feature flags).
5. **Secrets**: values injected at runtime (admin passwords, client secrets, TLS/ACME material).

## Repository layout (this project)

- **`deployments/<id>/`** — one bundle per target: `deployment.json`, `routing.json`, `services.json`, `config.json`
- **`schemas/`** — JSON Schema for those inputs
- **`scripts/compile.py`** — validates (optional) and writes **`.generated/<id>/`** (Caddyfile, compose, `resolved.json`)

## How to review this reference

- Start with `DEPLOYMENT_MODEL.md`, then `DEPLOY_LOCAL.md`.
- `EXAMPLES.md` points at `deployments/` as the concrete reference.
- Older contracts (`MANIFEST_CONTRACT.md`, `RENDERING_CONTRACT.md`) describe ideas that map to the bundle + compiler shape above.

## Running and debugging

- Local bring-up commands and secrets paths: `DEPLOY_LOCAL.md`
- Operational issues (browser HSTS, recreate after config changes, compose errors): `TROUBLESHOOTING.md`
- Re-print route URLs (same deployment args as `up.sh`, e.g. `127.0.0.1`): `python3 scripts/print_routes.py 127.0.0.1` — add `--compile` to refresh `resolved.json` first

