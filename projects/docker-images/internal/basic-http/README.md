# basic-http

Small **FastAPI** app that serves **static files** from a directory inside the container. **Mount your site from the host** onto the documented path so you can edit files without rebuilding the image.

## Web root (canonical mount)

| Path in container | Purpose |
|-------------------|--------|
| **`/srv/www`** | **Only** directory served as HTTP (with `html=True` for `index.html`). |

Override with env **`BASIC_HTTP_ROOT`** if you must (not recommended—prefer fixing the mount).

## Ports

- **`8080`** — HTTP (override with env **`PORT`**).

## Local development (uv)

```bash
cd projects/docker-images/internal/basic-http
uv sync
export BASIC_HTTP_ROOT="$HOME/my-site"
mkdir -p "$BASIC_HTTP_ROOT"
echo '<h1>hi</h1>' > "$BASIC_HTTP_ROOT/index.html"
uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8080
```

Open **http://127.0.0.1:8080/** and **http://127.0.0.1:8080/health**.

## Docker build

From **`projects/docker-images`**:

```bash
./scripts/build-local.sh internal/basic-http
# → local/basic-http:0.0.5
```

## Default behavior for `/` (no `index.html`)

If **`/srv/www/index.html`** does **not** exist, **`GET /`** (and **`POST /`**, **`PUT /`**, etc.) return **`application/json`** that **echoes the request**, including:

- **`service`**: **`basic_http_instance`**, **`basic_http_public_path`**, **`container_hostname`** — set with env (see below) so you can tell **which** replica answered when many share the same image behind Caddy.
- **`method`**, **`url`**, **`path`**, **`query`**, **`headers`** (raw pairs), **`cookies`**, **`client_ip`**, **`client`**, **`body`**.

**`HEAD /`** returns the same headers as that JSON would have, with **no body**.

**Identify the container:** set **`BASIC_HTTP_INSTANCE`** per compose service (e.g. **`blog`** vs **`docs`**). Optional **`BASIC_HTTP_PUBLIC_PATH`** (e.g. **`/blog/`**). Optional compose **`hostname:`** so **`container_hostname`** is readable. **Caddy** can add **`header_up X-…`** values; they show up inside **`headers`** in the echo (the app does not need custom code for that).

If you add **`index.html`** (in the image under **`default-site/`** or via a **volume mount**), **`GET /`** and **`HEAD /`** serve that file instead.

Optional env **`BASIC_HTTP_MAX_BODY_DUMP`** (bytes, default **`1048576`**) limits how much of the body is reflected in JSON when large.

## Run with a mounted site (read-write)

```bash
docker run --rm -p 8080:8080 \
  -v "$HOME/my-site:/srv/www" \
  local/basic-http:0.0.5
```

For now mounts are **read-write** by default (no `:ro`). Use **`:ro`** in compose when you want read-only.

## Multiple sites

Use **multiple containers** from the **same image**, each with a **different** **`-v`** host path → **`/srv/www`**, and different published ports or paths behind Caddy.

## Files

- **`config.md`** — compose handoff (ports, env, volumes).
- **`../../POC.md`** Phase 7.
