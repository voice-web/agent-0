# basic-http — deployment notes

Handoff for **docker compose** / ops. Image tag: **`local/basic-http:<version.txt>`** (internal semver, currently **`0.0.5`**).

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
| **`BASIC_HTTP_MAX_BODY_DUMP`** | **`1048576`** | Max bytes of request body to include in JSON echo on **`/`**. |
| **`BASIC_HTTP_INSTANCE`** | _(none)_ | **Stable label** for this replica (e.g. **`blog`**, **`site-a`**). Shown in JSON **`service`** and **`/health`**. |
| **`BASIC_HTTP_PUBLIC_PATH`** | _(none)_ | **Hint** for the edge path you expect (e.g. **`/blog/`**). For humans; Caddy may also send real path via headers. |
| **`HOSTNAME`** | Docker default | Container hostname (set **`hostname:`** in compose to make it readable). Echoed as **`container_hostname`**. |

### Which container answered? (multi-path deploy)

1. **Env (recommended):** set **`BASIC_HTTP_INSTANCE`** (and optionally **`BASIC_HTTP_PUBLIC_PATH`**) **per compose service** so **`/`** JSON echo and **`/health`** show which backend you hit.
2. **Proxy headers:** anything Caddy adds with **`header_up`** appears in the echo’s **`headers`** list (e.g. original URI, route name). Example:

```caddy
handle_path /blog/* {
	reverse_proxy basic-http-blog:8080 {
		header_up X-Edge-Path /blog
		header_up X-Basic-Http-Expected blog
	}
}
```

Use names you choose; **`basic-http` does not interpret** these unless you add code later—they’re for you reading the JSON.

3. **`path`** / **`url`** in the echo are what **this container** received after Caddy **`handle_path`** strip (often **`/`** for the backend even when the browser hit **`/blog/`**).

## Volumes

- **Optional:** bind-mount host site directory → **`/srv/www`** (read-write by default in your compose).
- **Without `index.html`** in **`/srv/www`**, **`/`** returns a **JSON echo** of the incoming request (see **`README.md`**). Add **`index.html`** (file in mount or in image) to serve a normal home page for **`GET/HEAD /`**.

## Secrets

None for this service.

## Compose hints

- **Service A:** `volumes: ["~/sites/a:/srv/www"]` → Caddy route **`/a/`** → `basic-http-a:8080`.
- **Service B:** `volumes: ["~/sites/b:/srv/www"]` → another route or port.
- **Healthcheck:** `GET …/health` → **200** JSON including **`status`**, **`root`**, **`basic_http_instance`**, **`container_hostname`** when set.

## Upstream

- [FastAPI StaticFiles](https://fastapi.tiangolo.com/tutorial/static-files/)
