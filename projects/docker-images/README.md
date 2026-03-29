# docker-images

Central place to **build and publish** Docker images used across compose stacks (ingress with **Caddy**, **Keycloak**, and other services). This directory is intended to become its **own Git repository** later; until then it lives under **`agent-0/projects/docker-images`**.

## Goals

- One repo, **many images**, each with its own **`Dockerfile`**, **`version.txt`**, **`CHANGELOG.md`**, and **`config.md`** (deployment notes for compose authors).
- Support **local build + local “publish”** (load/tag for `docker compose`) and, later, push to **Oracle Container Registry** (or another registry).
- **Secrets** never committed: use **`~/.secrets/`** (or your env) for Keycloak admin passwords, Caddy ACME accounts, etc.
- **Compose stacks** (elsewhere) will pull these images or use `build:` context pointing here—e.g. **Caddy** as path-based ingress, **Keycloak** and **Open WebUI** behind Caddy where needed.

## Layout

```text
projects/docker-images/
  README.md                 # This file
  POC.md                    # Phased plan to build each image type
  scripts/
    build-local.sh          # Build (and optional tag) from a service directory
  internal/                 # Images for private / first-party services
    <service-name>/
      Dockerfile
      version.txt           # See "Versioning" (internal: e.g. 0.0.1)
      CHANGELOG.md
      config.md             # Ports, env, volumes, secrets — for compose / ops
  external/                 # Images wrapping or extending third-party bases
    caddy/   keycloak/   open-webui/   …
    <service-name>/
      Dockerfile
      version.txt           # See "Versioning" (external: upstream version)
      CHANGELOG.md
      config.md
```

### `config.md` (per image)

Each **`internal/*`** and **`external/*`** directory should include **`config.md`**: short, **deployment-oriented** notes (exposed ports, required **environment variables**, **volumes**, **health** path, **`~/.secrets`** expectations, and hints for **docker compose**—not a repeat of upstream docs, but what *you* need to run this image in your stacks.

### Downstream: deployment list + compose

A sensible next step is a **separate project** that owns the **manifest** (“what to deploy”) and **`docker-compose.yml`** (wiring, networks, depends_on, published ports). This repo stays **image definitions**; **`config.md`** here is the handoff so compose authors know how to wire each service without re-reading Dockerfiles.

### `internal/` vs `external/`

| Directory   | Use for |
|------------|---------|
| **`external/`** | Wrappers around **vendor** bases (official Caddy, Keycloak, databases, …), plus small additions (config baked in, themes, realm import assets). |
| **`internal/`** | **Your** apps and tools. **`internal/basic-http`** — FastAPI static server; mount site files at **`/srv/www`**. See **`internal/basic-http/README.md`**. |

### Versioning

- **`external/*` — `version.txt` = upstream / vendor version**  
  One line, **the same version you pin in `FROM`** (e.g. Caddy **`2.8.4`**, Keycloak **`26.0.5`**, Open WebUI **`v0.8.12`**). The Docker tag becomes **`local/<name>:<that-string>`**, so `docker compose` and humans can see which upstream release the image tracks. When you bump the base image, update **`Dockerfile`**, **`version.txt`**, and **`CHANGELOG.md`** together.

- **`internal/*` — `version.txt` = your image semver**  
  Start at **`0.0.1`** and bump when **your** app or wrapper changes (independent of a vendor tag unless you embed one in the name).

- The build script reads **`version.txt`** and tags **`${IMAGE_PREFIX}/${IMAGE_NAME}:${version}`** (see **`scripts/build-local.sh`**).

### Changelog

Each service directory has its own **`CHANGELOG.md`** ([Keep a Changelog](https://keepachangelog.com/) style is fine). Record base-image bumps and behavioral changes.

## Secrets

- Put **Keycloak** admin credentials, **Caddy** ACME/Let’s Encrypt keys, TLS material, and similar files under **`~/.secrets/`** (or another path outside the repo).
- **Compose** should mount or env-substitute from there; do **not** copy secrets into image layers unless you fully understand the risk (generally avoid).

## Build (local)

From **`projects/docker-images`**:

```bash
# Build one image; path is under internal/ or external/
./scripts/build-local.sh external/caddy
./scripts/build-local.sh external/keycloak
./scripts/build-local.sh external/open-webui
./scripts/build-local.sh internal/basic-http
```

Default local name pattern: **`local/<service-name>:<version>`** (override with env vars documented in the script).

## Roadmap (high level)

1. **Caddy** — ingress image with versioned **`Dockerfile`**; path routing POC in **`POC.md`**.
2. **Keycloak** — wrapped official image; realm/theme extensions as needed; integrate behind Caddy.
3. **Open WebUI** — wrapped **`ghcr.io/open-webui/open-webui`** at the version in **`version.txt`**; compose + Caddy routing per **`POC.md`**.
4. **Compose POC** — single host port on Caddy, routes to Keycloak, Open WebUI, and other backends.
5. **Registry** — extend **`build-local.sh`** (or add **`scripts/publish-registry.sh`**) for Oracle OCIR push.
6. **`internal/basic-http`** — when you need a tiny first-party probe or stub service (**`version.txt`** from **`0.0.1`**).

## Related

- **`POC.md`** — step-by-step plan to implement each container type and the compose ingress/auth POC.
