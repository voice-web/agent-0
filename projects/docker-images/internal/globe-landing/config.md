# globe-landing — deployment notes

Handoff for docker compose / ops.

## Role

Serves the VAP globe-landing static web site as a simple HTTP static container.

## Runtime

- Command: `python3 -m http.server ${PORT} --bind 0.0.0.0 --directory /srv/www`
- Root: `/srv/www`
- Texture asset: `site/assets/earth-equirect.jpg` (bundled in image)

## Port

- `8080` in container

## Environment

- `PORT` (default `8080`)

## Health

- No dedicated `/health` endpoint (static server only).
- For liveness checks, use `GET /` expecting HTTP 200.

## Compose hint

Typical usage behind Caddy:
- `/` (or non-API routes) -> `globe-landing:8080`
- Keep API routes proxied to an API container separately.

## Maintenance

- To refresh the Earth texture before build:
  - `./internal/globe-landing/scripts/fetch-earth-texture.sh`

