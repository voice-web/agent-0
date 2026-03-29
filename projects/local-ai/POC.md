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

## Phase 1 — Baseline (Ollama)

Skip or verify if you already did this on this machine.

- [ ] **asdf (optional):** Repo root **`.tool-versions`** and **`projects/ollama/.tool-versions`** pin **`ollama 0.17.0`** so `asdf install` / `asdf local` match the CLI you use.
- [ ] `ollama --version` and `curl -s http://127.0.0.1:11434/api/tags` succeed.
- [ ] **If `/api/tags` already lists models:** You may already have the **agent-0** baseline: **`qwen2.5:0.5b`** (pulled), **`node-0:latest`** (custom, built from **`../ollama/custom-models/node-0`**), and **`codellama:latest`** (pulled separately; not in repo). See **`../ollama/README.md`** § *What shows up in GET /api/tags*.
- [ ] Otherwise `ollama pull <your-model>` (same tag you will use in WebUI and Open Interpreter—can be `qwen2.5:0.5b`, `node-0`, `codellama`, or a larger model from the main **README**).
- [ ] Create sandbox directory, e.g. `~/BusinessSandbox`.
- [ ] Add dummy files: `notes.md`, `hello.py` (optional sanity check).

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
- [ ] **C:** Run `python3 scripts/fetch_url.py https://example.com -o ~/BusinessSandbox/page.html` (or similar).

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
python3 scripts/fetch_url.py "https://example.com" -o ~/BusinessSandbox/example.html
```

**Linux:** If `host.docker.internal` fails, see the main **README** bridge section (host network or `172.17.0.1`).
