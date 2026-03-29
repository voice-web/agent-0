# POC plan — docker-images

Phased plan to implement each **image type** and prove **Caddy ingress + Keycloak + Open WebUI** (and stubs) in compose. Adjust versions and paths when this directory becomes a standalone repo.

**Versioning:** For **`external/*`**, **`version.txt`** = **upstream** version (must match **`FROM`**). For **`internal/*`**, start **`version.txt`** at **`0.0.1`**.

---

## Phase 0 — Repository scaffolding

**Goal:** Conventions and tooling work before “real” stack integration.

- [ ] Confirm tree: **`external/<name>`**, **`internal/<name>`**, each with **`Dockerfile`**, **`version.txt`**, **`CHANGELOG.md`**, **`config.md`** (deployment notes for compose).
- [ ] **`scripts/build-local.sh`** builds from a given path, reads **`version.txt`**, tags **`local/<name>:<version>`** (configurable **`IMAGE_PREFIX`**, **`IMAGE_NAME`** override).
- [ ] Document in **`README.md`**: secrets in **`~/.secrets`**, no secrets in git.
- [ ] (Optional) **`.gitignore`** at project root when split to its own repo: `**/.env`, `**/secrets/`.

**Exit:** Running `./scripts/build-local.sh external/caddy`, `external/keycloak`, and `external/open-webui` produces tags **`local/caddy:<upstream>`**, **`local/keycloak:<upstream>`**, **`local/open-webui:<upstream>`**.

---

## Phase 1 — `external/caddy` (ingress)

**Goal:** A **versioned, buildable** Caddy image you own (thin wrapper over official Caddy).

| Step | Task |
|------|------|
| 1.1 | **`Dockerfile`**: `FROM` a **pinned** official tag (e.g. `caddy:2.8.4-alpine`); `COPY` a default **`Caddyfile`** or document **runtime mount** in compose. |
| 1.2 | **`version.txt`**: **upstream Caddy version** only (e.g. **`2.8.4`**), must match the tag in **`FROM`**. |
| 1.3 | **`CHANGELOG.md`**: note wrapper changes; version headings align with **`version.txt`**. |
| 1.4 | **Local run POC:** `docker run --rm -p 8080:80 local/caddy:2.8.4` → **`GET /`** returns 200 or simple body. |
| 1.5 | **Path routing POC (single container):** Caddyfile with two **`handle_path`** / **`reverse_proxy`** targets to **dummy** backends (e.g. `httpbin` or two `whoami` containers on the same user-defined network)—proves **same listener, different paths** (see prior Caddy examples in your notes). |

**Risks:** Apps behind Caddy may need **subpath / strip_prefix** tuning; WebSockets and large uploads need extra directives.

**Exit:** Image builds reproducibly; path-based routing POC passes with two test upstreams.

---

## Phase 2 — `external/keycloak` (identity)

**Goal:** A **versioned** image based on **official Keycloak**, ready for compose and optional baked **realm/theme** later.

| Step | Task |
|------|------|
| 2.1 | **`Dockerfile`**: `FROM` **pinned** `quay.io/keycloak/keycloak:<version>` (or build stage if you adopt Keycloak’s build pattern later). |
| 2.2 | **`version.txt`**: **upstream Keycloak version** only (e.g. **`26.0.5`**), must match **`FROM`**. |
| 2.3 | **Secrets:** admin user/password from **env** or files under **`~/.secrets`** at **runtime**—never `ARG` secrets in Dockerfile for production. |
| 2.4 | **Local run POC:** `docker run` with documented **`KEYCLOAK_ADMIN`**, **`KEYCLOAK_ADMIN_PASSWORD`**, **`start-dev`** (dev only) or **`start`** + DB (prod-like)—pick one for POC and document it. |
| 2.5 | **Optional:** `COPY` a **realm export JSON** and import on startup (entrypoint script or documented `kc.sh import`)—defer if first milestone is “login screen reachable only.” |

**Risks:** Production Keycloak expects a **real DB**; dev mode is fine for POC only.

**Exit:** Keycloak admin console reachable on mapped port; image tag matches **`version.txt`** (e.g. **`local/keycloak:26.0.5`**).

---

## Phase 3 — `external/open-webui` (chat UI)

**Goal:** A **pinned** Open WebUI image under your naming convention; same versioning rule as other **`external/*`** images.

| Step | Task |
|------|------|
| 3.1 | **`Dockerfile`**: `FROM ghcr.io/open-webui/open-webui:<tag>` — use the **exact** tag (often **`v0.x.y`** or **`0.x.y`** per upstream). |
| 3.2 | **`version.txt`**: **same string** as that tag (e.g. **`v0.8.12`**). Bump **`Dockerfile` + `version.txt` + `CHANGELOG.md`** together when upgrading. |
| 3.3 | **Local run POC:** `docker run` with **`OLLAMA_BASE_URL`** pointing at host Ollama (e.g. **`http://host.docker.internal:11434`**) if you test on Mac—mirror your real compose env. |
| 3.4 | **Behind Caddy:** plan path prefix (e.g. **`/chat/`**) or separate hostname; WebSocket and long polling often need **`reverse_proxy` headers**—validate in Phase 4 compose. |

**Exit:** **`./scripts/build-local.sh external/open-webui`** → **`local/open-webui:v0.8.12`** (or whatever is in **`version.txt`**); UI loads when run with correct env.

---

## Phase 4 — Compose stack POC (Caddy → Keycloak + Open WebUI + stubs)

**Goal:** One **host port** on Caddy; **Keycloak**, **Open WebUI**, and stubs only on the Docker network.

- [ ] **`docker-compose.yml`** (in this project or a sibling **`compose/`** folder): services **`caddy`**, **`keycloak`**, **`open-webui`**, optional **`whoami-*`** stubs.
- [ ] Caddy routes e.g. **`/auth/`** → Keycloak (path prefix may need **`KC_HTTP_RELATIVE_PATH`** / proxy headers; budget **X-Forwarded-\*** and buffer settings).
- [ ] Caddy routes e.g. **`/chat/`** or **`/`** → Open WebUI (confirm **subpath** support or use dedicated hostname).
- [ ] Routes e.g. **`/api/...`** → stubs to validate **path carving** (`/api/entity/a` vs `/api/entity`).
- [ ] **Healthchecks** where supported; document **order** (`depends_on` + health) if needed.

**Exit:** From one host port: reach Keycloak, Open WebUI, and a stub path without publishing stub ports on the host.

---

## Phase 5 — Authentication integration (behind Caddy)

**Goal:** Caddy enforces or delegates auth (choose one path for POC).

| Option | Notes |
|--------|--------|
| **A. App-level OIDC** | Services trust Keycloak tokens; Caddy is TLS/path router only—simplest for many stacks. |
| **B. Caddy `forward_auth` / plugin** | Caddy calls Keycloak (or oauth2-proxy) before proxying; more moving parts. |

- [ ] Pick **A or B** for first POC; document in **`README.md`**.
- [ ] If **B**: spike **oauth2-proxy** or Caddy **forward_auth** in front of one stub route.

**Exit:** One protected path behavior demonstrated (even if only stub).

---

## Phase 6 — Registry publish (Oracle OCIR)

**Goal:** Extend automation beyond local tags.

- [ ] Add **`scripts/publish-registry.sh`** (or flags on **`build-local.sh`**) that: build → **`docker tag`** → **`docker push`** to **`ocir.io/<tenancy>/<repo>/<image>:<version>`** (exact URL per your tenancy).
- [ ] Auth: **API key / auth token** via **`~/.secrets`** or CI variables—never in repo.
- [ ] Document **first push** and **compose `image:`** switch from **`local/...`** to registry.

**Exit:** One image pushed and pulled on a clean machine (or second host).

---

## Phase 7 — `internal/basic-http`

**Goal:** Minimal **first-party** image for static sites, health checks, or stub upstreams behind Caddy.

- [x] FastAPI + **`StaticFiles`** from **`/srv/www`** (**`BASIC_HTTP_ROOT`**); **`GET /health`**.
- [x] **`version.txt`** **`0.0.1`**; **`CHANGELOG.md`**, **`config.md`**, **`Dockerfile`** with **uv** (`uv sync` in image build).
- [ ] Optional: add **`uv.lock`** locally (`uv lock`) and switch Dockerfile to **`uv sync --frozen`** for reproducible builds.

**Exit:** Used as upstream in Caddy path-routing tests when you need a controllable app.

---

## Suggested order of execution

1. Phase **0** → **1** (Caddy) → **2** (Keycloak) → **3** (Open WebUI); Caddy first if serial (fastest loop).  
2. Phase **4** compose POC.  
3. Phase **5** auth spike.  
4. Phase **6** registry.  
5. Phase **7** when needed.

---

## Checklist summary

| Phase | Focus |
|-------|--------|
| 0 | Tree, `build-local.sh`, docs |
| 1 | `external/caddy` + path routing POC |
| 2 | `external/keycloak` + run POC |
| 3 | `external/open-webui` + run POC |
| 4 | Compose: Caddy edge + Keycloak + Open WebUI + stubs |
| 5 | Auth pattern (OIDC at app vs proxy) |
| 6 | Oracle registry push |
| 7 | `internal/basic-http` |
