# default-api-json — deployment notes

Handoff for docker compose / ops.

## Role

JSON-only stub for the API host (`api.worldcliques.org`).
Used to validate edge routing + default proxy error semantics.

## Port

- `8080` — HTTP inside the container (published by Caddy).

## Environment

- `PORT` (default `8080`)
- `CORS_ALLOW_ORIGINS` (default `*`)
  - use either `*` or a comma-separated list, e.g. `https://worldcliques.org,https://admin.worldcliques.org`
- `CORS_ALLOW_HEADERS` (default `Authorization,Content-Type`)

## CORS requirements (summary)

For a typical SPA calling the API:
- browser sends `Authorization: Bearer <token>`
- browser performs a preflight `OPTIONS` if needed
- API must respond with:
  - `Access-Control-Allow-Origin`
  - `Access-Control-Allow-Headers` (must include `Authorization`)
  - `Access-Control-Allow-Methods`

This container already sets CORS via FastAPI/Starlette middleware.

## Caddy expectations (host split)

Expected routing:
- `api.worldcliques.org` => this container
- `worldcliques.org` and `*.worldcliques.org` => the HTML container

For websocket routes (if/when you add them to the API service):
- configure Caddy `reverse_proxy` to pass through `Upgrade`/`Connection` headers
- validate long-lived connections (timeouts/buffers)

## Health

- `GET /health` => `{"status":"ok"}`

