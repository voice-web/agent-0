# deploy-docker (reference)

This directory is a **reference implementation** (mostly docs + examples) for how to separate deployment concerns over time:

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

## Recommended repository structure

When you implement the renderer, keep the inputs separate:

- `manifests/` (what logical services to deploy)
- `routing/` (how ingress maps to logical services)
- `configs/` (env-specific params per logical service)
- `images/` (optional lookup table of image tags by logical service)

## How to review this reference

- Start with `MANIFEST_CONTRACT.md` to understand the manifest schema.
- Then read `EXAMPLES.md` and the sample files in `examples/`.
- Finally review `RENDERING_CONTRACT.md` to see what the renderer must output.

## Running and debugging

- Local bring-up commands and secrets paths: `DEPLOY_LOCAL.md`
- Operational issues (browser HSTS, recreate after config changes, compose errors): `TROUBLESHOOTING.md`
- Re-print route URLs (same deployment args as `up.sh`, e.g. `127.0.0.1`): `python3 scripts/print_routes.py 127.0.0.1` — add `--compile` to refresh `resolved.json` first

