# basic-http — deployment notes

Handoff for **docker compose** / ops. Image tag: **`local/basic-http:<version.txt>`** (internal semver, currently **`0.0.1`**).

## Role

Serve **static files** (HTML, assets) from a **single directory**. Use for simple sites, stubs behind Caddy, or local experiments. Same image, **different mounts** = different sites.

## Canonical mount

| Container path | Host (example) | Mode |
|----------------|----------------|------|
| **`/srv/www`** | **`./sites/blog`** or **`~/sites/docs`** | **Read-write** for now (omit `:ro`); switch to **`:ro`** when you want immutability. |

Do not mount over **`/app`** unless you know what you’re doing (application code lives there).

## Ports

| Container | Notes |
|-----------|--------|
| **8080** | HTTP. One port **per container instance**. Override with **`PORT`**. |

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| **`BASIC_HTTP_ROOT`** | **`/srv/www`** | Directory to serve (must exist and be a directory at startup). |
| **`PORT`** | **`8080`** | Uvicorn listen port. |

## Volumes

- **Required for real content:** bind-mount host site directory → **`/srv/www`**.
- Without a mount, the image contains an **empty** **`/srv/www`** (you get 404s until you add files or mount).

## Secrets

None for this service.

## Compose hints

- **Service A:** `volumes: ["~/sites/a:/srv/www"]` → Caddy route **`/a/`** → `basic-http-a:8080`.
- **Service B:** `volumes: ["~/sites/b:/srv/www"]` → another route or port.
- **Healthcheck:** `GET http://127.0.0.1:8080/health` → **200** JSON `{"status":"ok","root":"..."}`.

## Upstream

- [FastAPI StaticFiles](https://fastapi.tiangolo.com/tutorial/static-files/)
