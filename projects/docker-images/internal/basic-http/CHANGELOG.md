# Changelog

## [0.0.5] - 2026-03-29

- JSON echo includes **`service`**: **`basic_http_instance`**, **`basic_http_public_path`**, **`container_hostname`** (from env). **`/health`** includes the same three as top-level keys plus **`status`** / **`root`**.

## [0.0.4] - 2026-03-29

- JSON echo adds **`client_ip`**: **`peer`** (TCP source), **`x_forwarded_for_*`**, **`x_real_ip`**, **`forwarded_header_raw`**, **`best_effort_remote_ip`** (first XFF hop → X-Real-IP → peer host).

## [0.0.3] - 2026-03-29

- **`/`** returns **JSON request echo** (method, URL, query, raw headers, cookies, client, body as UTF-8 or base64) when **`index.html`** is absent.
- **`GET/HEAD /`** still serve **`index.html`** from **`/srv/www`** when that file exists (mounted sites unchanged).
- **`BASIC_HTTP_MAX_BODY_DUMP`** (default 1 MiB) caps bytes included in the JSON body fields.

## [0.0.2] - 2026-03-29

- Baked-in **default** **`/srv/www/index.html`** (hello world) when no volume is mounted; mount still replaces **`/srv/www`**.

## [0.0.1] - 2026-03-29

- Initial **basic-http**: FastAPI + `StaticFiles`, site root **`/srv/www`** (`BASIC_HTTP_ROOT`).
- **`GET /health`** JSON for compose healthchecks.
- Image built with **uv** (`uv sync` in Dockerfile).
