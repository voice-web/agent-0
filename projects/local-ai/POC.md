# local-ai — POC checklist

**Goal:** A local stack that can **pull context from the internet** (search or URLs), then **change files and run code** on your machine—using **one Ollama** on the host, with work concentrated under a **sandbox folder**.

**Canonical repo:** `agent-0` → `projects/local-ai/`.

**Docker POC (macOS):** Use **OrbStack** + **`docker compose`** like other voice-web projects (see **`DOCKER.md`**).

---

## Definition of done (POC)

- [ ] **External information:** Web search (Open WebUI) **or** saved page text via `scripts/fetch_url.py` into the sandbox.
- [ ] **One local model:** Same Ollama model for research UI and Open Interpreter (e.g. `llama3.1:8b` or `gemma2:9b`).
- [ ] **Filesystem actions:** Open Interpreter creates/edits files **only** under your sandbox; **no** auto-run until you trust the flow.

---

## Phase 1 — Baseline (Ollama) — **all required**

Nothing in this phase is optional. Finish everything here before Phase 2.

- [ ] **Ollama CLI:** `ollama --version` runs (you may see MLX warnings on stderr; see **`../ollama/scripts/ollama-bg`** if you run the server from a script).
- [ ] **Ollama API:** `curl -s http://127.0.0.1:11434/api/tags` returns **HTTP 200** and JSON with at least one **`models`** entry.
- [ ] **Models:** Pull or build what you need for WebUI + Interpreter (e.g. **`qwen2.5:0.5b`**, **`node-0`** from **`../ollama/custom-models/node-0`**, **`codellama`**). See **`../ollama/README.md`** § *What shows up in GET /api/tags*.
- [ ] **asdf (if you use it):** Repo root and **`projects/ollama/.tool-versions`** pin **`ollama 0.17.0`** so the CLI matches.
- [ ] **Sandbox directory:** **`~/vap-sandbox-0`** exists (`mkdir -p ~/vap-sandbox-0`) — **outside** **agent-0**. (Later you may widen scope to **`$HOME`**.)

### Starter files in the sandbox (required)

- [ ] **`~/vap-sandbox-0/notes.md`** and **`~/vap-sandbox-0/hello.py`** exist. Canonical copies are in **`sandbox-starters/`** in this folder:

```bash
cp sandbox-starters/notes.md sandbox-starters/hello.py ~/vap-sandbox-0/
```

### Verify Phase 1

From **`projects/local-ai`**:

```bash
./scripts/verify-phase1.sh
```

Exits **0** only if: Ollama responds, `/api/tags` lists at least one model, and **`~/vap-sandbox-0`** contains **`notes.md`** and **`hello.py`**.

**Status (reference machine, 2026-03-29):** Phase 1 verified with **`./scripts/verify-phase1.sh`**.

---

## Phase 2 — Research leg (“read from the internet”)

Pick **one** path for the POC (add others later):

| Path | When to use |
|------|-------------|
| **A. Open WebUI + Web Search** | You want UI + RAG + search; configure a backend in admin settings (see main README). |
| **B. Manual** | Fastest: copy/paste or download into sandbox, chat in WebUI over files. |
| **C. `scripts/fetch_url.py`** | Fetch a URL to a text file in the sandbox, then point the model at that file. |

- [ ] **A:** OrbStack (or Docker engine) running; WebUI up via `docker compose` in this folder; models visible; web search enabled if desired.
- [ ] **B:** At least one real note/file in sandbox used in a chat.
- [ ] **C:** `python3 scripts/fetch_url.py https://example.com -o ~/vap-sandbox-0/page.html` (from `projects/local-ai`).

---

## Phase 3 — Action leg (Open Interpreter)

- [ ] Python venv with `open-interpreter` installed.
- [ ] `cd` **into sandbox** → `interpreter --model ollama/<same-model-as-ollama-pull>`.
- [ ] Single scripted task works (e.g. “add a function to `hello.py` and update `notes.md`”).
- [ ] Confirm-before-run stays on until you are comfortable.

---

## Phase 4 — Bridge

- [ ] Open WebUI container uses `OLLAMA_BASE_URL` → host Ollama (see `docker-compose.yml`; macOS OrbStack uses `host.docker.internal:11434`).
- [ ] Interpreter uses default local Ollama (`http://localhost:11434`).
- [ ] No duplicate Ollama inside the WebUI container.

---

## Phase 5 — Hardening (after POC)

- [ ] Pin WebUI image tag (not only `:main`) if you want reproducible deploys.
- [ ] Document your **exact** model name in this file or a local `MODEL.txt` in sandbox.
- [ ] Optional: self-hosted **SearXNG** for web search without commercial APIs.
- [ ] Optional: run Interpreter in Docker with **only** sandbox mounted.

---

## Quick commands (from this directory)

```bash
# WebUI — OrbStack on macOS (or Docker Desktop); Ollama on host :11434
docker compose up -d

# Fetch URL into sandbox (stdlib only)
python3 scripts/fetch_url.py "https://example.com" -o ~/vap-sandbox-0/example.html
```

**Linux:** If `host.docker.internal` fails, see the main **README** bridge section (host network or `172.17.0.1`).

---

## Last step (future): scripted, repeatable “deploy the POC”

**Not implemented yet** — this is the target pattern.

On a **new machine**, you should eventually be able to run something like **one entrypoint** (e.g. `scripts/deploy-poc.sh` or a small CLI) that:

1. **Runs each phase in order** — prerequisites checks, sandbox + starters, Docker/OrbStack + Compose for WebUI, optional Interpreter venv hints, etc.
2. **Verifies after each step** — same idea as **`scripts/verify-phase1.sh`**: exit non-zero with a clear message so you never assume a silent failure.
3. **Stays idempotent where possible** — safe to re-run; skip or no-op when already satisfied.

Today, **`verify-phase1.sh`** is the first example of that pattern. Later, add **`verify-phase2.sh`**, **`verify-phase3.sh`**, … or one orchestrator that calls phase scripts and gates on each exit code. The POC checklist above stays the **spec**; the scripts become the **automation**.

When you add automation, link the entrypoint here and keep **manual** steps documented for debugging.
