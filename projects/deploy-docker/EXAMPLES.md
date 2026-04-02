# Examples (reference)

These examples are minimal and focus on the layered contract:

1. `manifests/infra.json` — external services: `caddy`, `keycloak`
2. `manifests/services-dev.json` — internal services: `default-html`, `default-api-json`
3. `routing/dev-routing.json` — how hosts route to logical services
4. `configs/dev.json` — per-environment env vars and mount sources

They are intentionally small so you can review them quickly and map them to your existing `render-compose.py` approach.

