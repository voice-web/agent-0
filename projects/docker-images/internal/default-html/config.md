# default-html — deployment notes

Handoff for docker compose / ops.

## Role

Default HTML host for `worldcliques.org` (web UI host).
Serves the default rotating globe landing page and a starfield-based `error.html`.

## Port

- `8080` — HTTP inside the container (published by Caddy).

## Environment

- `BASIC_HTTP_ROOT` (default `/srv/www`) — static root.
- `PORT` (default `8080`) — uvicorn listen port.

## Volumes (recommended)

Mount globe-landing site assets into `/srv/www` so the landing + starfield can render:
- `/srv/www/css/styles.css` (mount `vap/projects/globe-landing/site/css`)
- `/srv/www/js/globe.js` (mount `vap/projects/globe-landing/site/js`)
- `/srv/www/config/defaults.json` (mount `vap/projects/globe-landing/site/config`)
- `/srv/www/api/default/web/config.json` (mount `vap/projects/globe-landing/site/api/default/web`)
- `/srv/www/assets/*` (mount `vap/projects/globe-landing/site/assets`)

## Caddy expectations (host split)

If you deploy with host-based routing:
- `api.worldcliques.org` => JSON/API container
- `worldcliques.org` and `*.worldcliques.org` => this container

For default error behavior:
- This container returns HTML `error.html` for missing non-asset paths (404) and for 500s.
- When the upstream itself is down (e.g., 502/504), configure Caddy `handle_errors` to also proxy to `/error.html` on this container.

## Health

- `GET /health` => `{"status":"ok", ...}`

