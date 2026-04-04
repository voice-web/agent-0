# agent-0

Workspace for local AI, deployment reference, and related experiments. Work is organized under **`projects/`**.

## Projects

| Project | Purpose |
|---------|---------|
| [**projects/ollama**](projects/ollama/) | Reference docs (Ollama, Colima, tool-use, RAG/dev surveys), helper **scripts**, and **custom-models**. |
| [**projects/local-ai**](projects/local-ai/) | Private stack POC: Ollama + Open WebUI (Docker), Open Interpreter, sandbox workflow — see that README and **POC.md**. |
| [**projects/docker-images**](projects/docker-images/) | Dockerfiles and **build-local** scripts for **Caddy**, **Keycloak**, **default-html**, **default-api-json**, **globe-landing**, etc.; handoff notes in per-image **config.md**. |
| [**projects/deploy-docker**](projects/deploy-docker/) | Reference **deployment bundles** (`deployments/<id>/`), **compile.py** → **`.generated/`**, **up.sh** / **down.sh**; model in **DEPLOYMENT_MODEL.md**, local runbook **DEPLOY_LOCAL.md**. |
| [**projects/deploy**](projects/deploy/) | Minimal **Caddy + basic-http** compose stack; **render-compose.py** from template + **versions.manifest.json**. |
| [**projects/docs**](projects/docs/) | Shared notes, runbooks, and **doc index** (Oracle VM, deploy VAP, Nmap, **entity schema contract**, …). |

## Guiding principles — entity model

When we talk about a **schema** in this repo, we standardize on: **schema = JSON contract for one entity type** (`*.schema.json`: name, version, primary key, flat field paths, optional example **shape**). The **master schema** is the **meta-contract** for those schema **files**.

- **Vocabulary + reference POC** (abeja-reina `.ray` output): [`projects/docs/entity-schema-contract.md`](projects/docs/entity-schema-contract.md)
- **Platform direction** (everything as an entity, **transforms**, relationship/action ideas, catch-all shapes for OpenAPI-like blobs, **incremental** adoption — code now, extract patterns later): [`projects/docs/guiding-principles-entity-model.md`](projects/docs/guiding-principles-entity-model.md)

**Note:** **deploy-docker**’s **`schemas/`** is today **JSON Schema for deployment manifests** — we intend to **converge** toward the entity-first model over time; see the guiding doc for intent vs current layout.

---

The **`.seed`** symlink at the repo root (if present) points at shared seed content from **abeja-reina** for Cursor prompts.

**Sandbox (local-ai / Open Interpreter):** **`~/vap-sandbox-0`** — working directory **outside** this repo (`mkdir -p ~/vap-sandbox-0`). Seed **`notes.md`** / **`hello.py`** from **`projects/local-ai/sandbox-starters/`**; verify with **`projects/local-ai/scripts/verify-phase1.sh`**. See **`projects/local-ai/README.md`**.

**asdf:** **`.tool-versions`** at the repo root pins **`ollama 0.17.0`** (same pin as **`projects/ollama/.tool-versions`**) so `asdf` can select that Ollama build when you work from the repo root.
