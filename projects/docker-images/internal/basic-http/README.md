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
# → local/basic-http:0.0.1
```

## Run with a mounted site (read-write)

```bash
docker run --rm -p 8080:8080 \
  -v "$HOME/my-site:/srv/www" \
  local/basic-http:0.0.1
```

For now mounts are **read-write** by default (no `:ro`). Use **`:ro`** in compose when you want read-only.

## Multiple sites

Use **multiple containers** from the **same image**, each with a **different** **`-v`** host path → **`/srv/www`**, and different published ports or paths behind Caddy.

## Files

- **`config.md`** — compose handoff (ports, env, volumes).
- **`../../POC.md`** Phase 7.
