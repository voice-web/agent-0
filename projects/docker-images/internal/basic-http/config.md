# basic-http — deployment notes (template)

**Status:** Image not implemented yet. Fill this in when **`Dockerfile`** exists.

Handoff for **docker compose** / ops. Image tag: **`local/basic-http:<version.txt>`** (internal semver, starting **`0.0.1`**).

## Role

Minimal first-party HTTP service (health probe, stub upstream for Caddy path tests, etc.).

## Ports

| Container | Notes |
|-----------|--------|
| _TBD_ | e.g. **8080** |

## Environment

_TBD_ — list required and optional vars.

## Volumes

_TBD_ — usually none for a stateless stub.

## Secrets

Typically **none** for a stub; document if you add auth.

## Compose hints

- Internal network only; reached via **`http://basic-http:<port>`** from Caddy.

## Health

_TBD_ — e.g. **`GET /health`** → **200**.
