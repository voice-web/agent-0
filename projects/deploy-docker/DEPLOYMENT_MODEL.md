# Deployment model (deploy-docker)

This document is the **single place** we align on how routing, manifests, configuration, and the edge work together — before we implement generators, `up.sh`, or CI. It is **design authority** for refactors; operational how-to stays in `DEPLOY_LOCAL.md` and friends until they are rewritten to match this model.

---

## Goals

1. **Three separable inputs** (each versionable and eventually movable to its own repo):
   - **Routing** — how traffic reaches services (today: compile to Caddy; later: Kubernetes Ingress or Gateway API).
   - **Manifest** — which logical services exist and their deploy-time shape (images, ports, mounts, dependencies).
   - **Config** — environment-specific values (feature flags, public URLs, TLS mode, edge port mappings, …) and **references** to secrets (never inline secrets).

2. **One shared edge** (Caddy locally; Kong or another ingress in Kubernetes later). Routes from **all active deployments** are **merged** into one edge config. Redeploying the edge when a deployment changes is expected and normal.

3. **Additive deployments** — multiple logical deployments can coexist; each contributes services (labels) and route fragments. **Compile** step merges routes with explicit **ordering** and **conflict detection**.

4. **Flux-style workflow (target state)** — edit **source** JSON/YAML in git → open PR → **CI validates** schemas and **generates** artifacts → merge → **downstream** applies (here: `docker compose` or copy to cluster; there: Flux applies manifests). Local `up.sh` can mirror “validate + generate + apply” without git, but the **same schemas and compilers** should power both.

5. **Schemas first** — JSON Schema (or similar) for routing, manifest, and config so validation is automatable and artifacts can live in separate versioned packages/repos later.

---

## Artifacts and directories (proposed)

| Role | Source (human/PR) | Generated (CI or `up`) |
|------|-------------------|-------------------------|
| Routing IR | `routing.json` (or shared profile + patch) | `caddy/Caddyfile` fragment or full file; later `ingress/*.yaml` |
| Services | `services.json` (manifest) | **`docker-compose.yml` (and overrides) under `.generated/`** — produced from templates |
| Environment config | `config.json` | Merged into compose env / passed to compilers |
| **Resolved bundle** | (derived) | **`resolved.json`** — fully merged inputs + computed values after overlays (for debug, audit, and “what we actually applied”) |

**Generated root** (`.generated/`): **this is what operators use for `docker compose`.** Any current `compose/*.yml` or static `examples/routing/Caddyfile-*` in git exists only **until** the compiler and `deployments/` inputs replace them; **when the new model is done, delete that legacy material** so the tree stays a single pipeline (sources → compile → `.generated/`). Do not keep hand-maintained compose or duplicate Caddyfiles “as examples” in this repo — samples should be **routing/services/config JSON** (or small deployment fixtures), not a second copy of machine output. Layout sketch:

- `.generated/edge/` — Compose project for **Caddy (or future ingress)** + merged `Caddyfile`
- `.generated/deployments/<deployment_id>/` — Compose project(s) for **application stacks** that attach to the shared network
- `.generated/resolved.json` (or per-deployment resolved shards) — post-merge truth

**Do not hand-edit generated files**; fix sources and re-run compile.

**Validation (every apply)** — On each **`up` / compile**, run **schema validation**, **policy checks**, and **route conflict detection**. If anything is inconsistent (duplicate host/path, missing secret ref, invalid port), **exit non-zero with a clear error** — no partial edge updates. CI runs the same checks before merge.

**Templates** — `templates/` for Mustache/Cherrypicked or similar strings used only by the **compiler** to turn manifest + config into Compose (and optionally systemd/K8s later).

**Deployments** — a **deployment** is a named bundle that points at (or embeds) a **routing profile + manifest + config** triple, e.g. `deployments/vm-host-infra-prod/` containing the three files or references to shared profiles.

---

## Routing

- **Source of truth**: structured `routing.json` (or equivalent), **no hand-edited Caddy** in the long run.
- **Ordering**: explicit in the IR (e.g. ordered `routes[]` or per-route `priority`). Compilers emit Caddy/Ingress in that order.
- **Merge policy**: when multiple deployments contribute routes, the **compiler** merges into one edge config in a deterministic order (e.g. by deployment id + route index). **Conflicts** (same listener + host + path, or mutually exclusive TLS/listener rules): **fail at compile/apply time** — no silent overrides unless explicitly modeled later.
- **Profiles** — reuse without copy-paste: e.g. `routing/profiles/local-path.json`, `routing/profiles/vm-host.json`, referenced by id from a deployment.

---

## Manifest (services)

- Describes **logical services** (name, image ref, container ports, mounts, health hints, capabilities).
- **Compiler** + **templates** → Docker Compose (and later other targets). **No checked-in “emergency” compose** after migration — fix manifests or templates and recompile.

---

## Config

- Per environment / tier: **dev**, **qa**, **prod** (files or overlays).
- Holds **feature flags**, **Keycloak public URL**, **HTML host lists**, **TLS mode**, **per-service edge port** vs **in-container listen port**, etc.
- **Secrets**: paths or env var **names** only; values live in `~/.secrets/...` or a secret manager.

---

## Docker: labels (filter like Kubernetes)

We standardize **labels** on containers so we can answer “what belongs to which deployment / team / manifest?” across **multiple Compose projects**.

**Suggested labels** (prefix TBD, e.g. `worldcliques.` or `com.worldcliques.`):

- `deployment=<deployment_id>`
- `manifest=<manifest_id>` (optional)
- `config=<config_id>` (optional)
- `role=edge|app|support`

**List labels on running containers**

```bash
# All running containers: name + full label map
docker ps -q | xargs -I{} docker inspect {} --format '{{.Name}} {{json .Config.Labels}}'
```

**Pretty-print one container’s labels**

```bash
docker inspect <container_name_or_id> --format '{{json .Config.Labels}}' | jq
```

**Filter by label** (Docker does not support label selector on `docker ps` natively; use inspect + jq)

```bash
docker ps -q | xargs -I{} sh -c 'docker inspect {} --format "{{.Name}} {{range \$k, \$v := .Config.Labels}}{{printf \"%s=%s \" \$k \$v}}{{end}}" | grep deployment=my-dep'
```

Or use **Compose** after deploy:

```bash
docker compose -p <project> ps
docker compose -p <project> config -q
```

**Inspect Compose-assigned labels** (Compose often sets `com.docker.compose.project`, `com.docker.compose.service`, `com.docker.compose.config-hash`):

```bash
docker inspect <container> --format '{{index .Config.Labels "com.docker.compose.project"}} {{index .Config.Labels "com.docker.compose.service"}}'
```

For a **k8s-like** workflow locally, treat **`deployment=...`** as your primary selector and script small helpers around `docker ps` + `inspect` + `jq`.

---

## Compose projects: multi-project (preferred — like Kubernetes)

**Preferred model** — closer to how you run Kubernetes today:

| Concern | Who owns it | Docker analogue |
|--------|-------------|------------------|
| **Edge / ingress** | Platform team | **One Compose project** (e.g. `wc-edge`) — Caddy + merged `Caddyfile` from `.generated/edge/` |
| **Application workloads** | Application teams (each can ship independently) | **Separate Compose project(s)** per team or per deployment — from `.generated/deployments/<id>/` |
| **Networking** | Shared cluster VPC | **External Docker network** (e.g. `wc-shared-net`) created by edge or bootstrap; app projects **attach** with `external: true` |

**Why multiple projects**

- Matches **separation of concerns**: infra deploys the edge once; app teams apply their own generated compose without editing a monolithic file.
- Matches **ownership** you already use with Flux (different actors, different lifecycles).

**Requirements**

- **One logical edge** still receives **merged routes** from the compiler (all teams’ routing IR merged + validated).
- All app stacks must share the **same external network** name the edge uses so Caddy can `reverse_proxy` to `service:port` DNS names.
- **Labels** remain mandatory so scripts can list “everything for deployment X” across projects (`docker inspect` / `jq`).

**Single monolithic Compose project** (one `docker compose -p wc` with every service), if we want it for local dev, is **only** another **compiler output** under `.generated/` — never a handwritten YAML we commit beside the generated tree.

---

## Flux / GitHub Actions parallel (local vs CI)

| Step | Kubernetes + Flux (your today) | deploy-docker (target) |
|------|----------------------------------|-------------------------|
| Edit | Config in git | `routing.json`, `services.json`, `config.json` in git (or submodule / separate repo) |
| PR | Human opens PR | Same |
| Validate | GHA runs schema + policy checks | Same (`ajv`, `jsonschema`, custom merge checks) |
| Generate | Bot or workflow emits YAML | Workflow (or `scripts/compile.sh`) emits `.generated/**` |
| Merge | Approved merge | Same |
| Apply | Flux reconciles cluster | Local: `docker compose -f .generated/...` (edge vs app projects); CI: optional push of `.generated/**` to an artifacts branch or store |

**Principle**: the **compiler** and **schemas** are shared; only the **apply** backend differs (docker compose vs kubectl/flux).

---

## Evolution: separate repos

To avoid rework when schemas/manifests/routing move out of `agent-0`:

1. **Publish schemas** as versioned packages (e.g. git repo `worldcliques/deploy-schemas` with semver tags; consumers pin `schema_version` in JSON).
2. **Manifests and routing** can live in `worldcliques/deploy-manifests` or per-product repos with **imports** or git submodules.
3. **This repo** (`deploy-docker`) keeps: compilers, templates, `up.sh`, **input-shaped examples** (JSON deployments / profiles), and **thin** wrappers that **pull** schema + referenced files at a pinned version (Makefile, `tools/pin.json`, or CI checkout).

**Rule of thumb**: no business logic inside schema JSON — only structure and refs — so compilers stay small and portable.

---

## Open points (not blockers for this doc)

1. **State for “active deployments”** — only CLI-invoked set vs persisted `state.json` vs “recompute from labels on each `up`.”
2. **Port-per-service local profile** — exact IR for `edge_listen_port` vs `container_port` (names in § Config are enough for design).
3. **Exact `.generated/` layout** — file names for edge vs per-deployment compose files; whether `down.sh` takes `--project` or discovers projects from `resolved.json`.

---

## Next implementation steps (when we agree)

1. Add JSON Schema files for **routing**, **manifest**, **config** (v1 minimal).
2. Add `scripts/compile.sh` (or Python): validate + conflict detection → emit **`.generated/edge/`**, **`.generated/deployments/...`**, **`resolved.json`**.
3. Refactor `up.sh` / `down.sh` to **only** drive **`docker compose` against generated files** (multi-project: edge first, then apps); labels on all services.
4. **Remove legacy** from the repo once parity is proven: old `compose/*.yml`, duplicate static Caddyfiles, and any scripts that bypass compile — **delete them**; documentation points only at `deployments/` inputs + `.generated/`.

---

## Document history

- **2026-04-02** — Initial consolidated model (routing + manifest + config, shared edge, Flux-like flow, labels, multi-repo evolution).
- **2026-04-02** — Multi-project Compose as preferred (infra edge vs app teams); generated compose is authoritative; strict validate/conflict checks; `resolved.json` formalized.
- **2026-04-02** — Post-migration cleanup: no long-lived legacy compose or hand Caddy examples in-tree; samples are JSON inputs only.
