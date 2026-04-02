# default-api-json

Default API/JSON container for the `api.worldcliques.org` host.

## Behavior

- `GET /health` => `{"status":"ok"}`
- Any other route => JSON `404` with:
  - `error.code = NOT_FOUND`
  - `error.message`
  - `path`, `method`
- Any `500` => JSON `INTERNAL_SERVER_ERROR`

## CORS baseline (token auth)

This container enables CORS so an SPA can call the API with:
`Authorization: Bearer <access_token>`

Key defaults:
- `allow_credentials=false` (avoid cookie semantics)
- allows headers including `Authorization` and `Content-Type`

If you want to tighten later, set `CORS_ALLOW_ORIGINS` to a specific origin or comma-separated origins.

## Token auth + Keycloak (expected)

This stub does not validate tokens yet. In the real API service:
- Clients should call Keycloak token endpoint with either:
  - browser login flow (SPA) => user tokens, then API calls with `Bearer` tokens
  - service-to-service flow => `client_credentials` => API calls with `Bearer` tokens
- API should validate the JWT signature using Keycloak JWKS.

## WebSockets note

Browsers can’t set `Authorization` headers during the WebSocket handshake.
Common patterns:
- pass token via query string (e.g. `wss://api.../ws?access_token=...`) and validate server-side
- or use cookies (you said you want to avoid)

Caddy’s `reverse_proxy` should be configured to support `Upgrade` for WebSocket traffic.

