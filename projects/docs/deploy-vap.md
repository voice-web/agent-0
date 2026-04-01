# Deploy - VAP (first pass)

Goal: deploy the current minimal stack (Caddy path routing + basic-http) from local source, and undo it cleanly.

## Scope for this pass

1. Check out the docker image source so we can build local images.
2. Check out deploy config so we can run a basic site.
3. Define setup and undo script flow.

## Repos / folders involved

Within `agent-0`:

- `projects/docker-images` - image definitions and build scripts.
- `projects/deploy` - compose stack, Caddy config, sites, manifest.

## Setup flow

### 1) Checkout source on VM

```bash
cd /opt/vap-src
git clone <agent-0-repo-url>
cd agent-0
```

If already cloned:

```bash
git fetch --all
git pull --ff-only
```

### 2) Build local images (scripted)

```bash
cd /opt/vap-src/agent-0/projects/docker-images
./scripts/build-local.sh external/caddy
./scripts/build-local.sh internal/basic-http
```

Expected tags from `projects/deploy/versions.manifest.json`:

- `local/caddy:2.8.4`
- `local/basic-http:0.0.5`

### 3) Prepare and start deploy stack

```bash
cd /opt/vap-src/agent-0/projects/deploy
python3 scripts/render-compose.py
docker compose up -d
docker compose ps
```

### 4) Verify

From the VM:

```bash
curl -sS http://127.0.0.1/
curl -sS http://127.0.0.1/labs/
```

From another device:

- `http://worldcliques.org/`
- `http://worldcliques.org/labs/`

## Undo flow

### A) Stop/remove stack (keep images)

```bash
cd /opt/vap-src/agent-0/projects/deploy
docker compose down
```

### B) Stop/remove stack + volumes

```bash
cd /opt/vap-src/agent-0/projects/deploy
docker compose down -v
```

### C) Remove built images (full local image reset)

```bash
docker image rm local/caddy:2.8.4 local/basic-http:0.0.5 || true
```

### D) Remove checkout (optional)

```bash
rm -rf /opt/vap-src/agent-0
```

## Script plan (to implement next)

### docker-images scripts

- Existing setup/build: `projects/docker-images/scripts/build-local.sh`
- Proposed undo: `projects/docker-images/scripts/remove-local-images.sh`
  - Remove tags defined in a passed manifest or explicit arguments.

### deploy scripts

- Proposed setup/start: `projects/deploy/scripts/up.sh`
  - Render compose, start stack, print URLs.
- Proposed undo: `projects/deploy/scripts/down.sh`
  - `docker compose down` with optional `--volumes`.

## Tomorrow discussion checklist

- [ ] Confirm checkout root (`/opt/vap-src/agent-0`).
- [ ] Confirm site content via **repos + symlinks** (or bind mounts); update compose paths if not under default `projects/deploy/sites/...`).
- [ ] Confirm script names and minimal flags (`up.sh`, `down.sh`, `remove-local-images.sh`).
- [ ] Confirm generated `docker-compose.yml` workflow (commit vs generate on host only).
- [ ] Confirm Oracle registry phase is post-local-only milestone.
