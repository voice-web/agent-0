# open-webui — deployment notes

Handoff for **docker compose** / ops. Image tag: **`local/open-webui:<version.txt>`** (upstream Open WebUI tag, e.g. **`v0.8.12`**).

## Role

Browser chat UI; talks to **Ollama** (or other backends) over HTTP. Often behind **Caddy** on **`/`** or a subpath (subpath may need extra proxy/WebSocket tuning).

## Ports

| Container | Notes |
|-----------|--------|
| **8080** | Default app port inside the official image (maps to host in compose as you choose) |

## Environment (common)

| Variable | Purpose |
|----------|---------|
| **`OLLAMA_BASE_URL`** | Ollama API URL. From container: often **`http://host.docker.internal:11434`** (Mac/Win) or host gateway IP on Linux |
| **`WEBUI_SECRET_KEY`** | Session/crypto; generate and set in prod |
| **`WEBUI_ADMIN_*`** | Optional headless first admin (see upstream docs) |

See [Open WebUI env docs](https://docs.openwebui.com/) for your version.

## Volumes

- Persist **`/app/backend/data`** (or path per upstream image) so chats/settings survive **`compose down`** without **`-v`**.

## Secrets (`~/.secrets` or env)

- Admin passwords, **`WEBUI_SECRET_KEY`**, API keys for search/embeddings if enabled.

## Compose hints

- Same Docker network as **Caddy** for reverse proxy; **do not** rely on host-only Ollama without **`extra_hosts`** / **`host.docker.internal`** where needed.
- **WebSockets** / long polling: Caddy **`reverse_proxy`** may need **`flush_interval`**, **`header_up`**, etc.—validate after upgrades.

## Health

- Use **`GET /`** or documented health path; add compose **`healthcheck`** when stable.

## Upstream reference

- [Open WebUI](https://github.com/open-webui/open-webui)
