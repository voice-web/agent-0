# local-ai — POC checklist

**Goal:** A local stack that can **pull context from the internet** (search or URLs), then **change files and run code** on your machine—using **one Ollama** on the host, with work concentrated under a **sandbox folder**.

**Canonical location:** Treat **`projects/local-ai/`** (this folder) as the unit you copy or archive; scripts do not **`source`** paths outside it.

**Docker POC (macOS):** Use **OrbStack** + **`docker compose`** like other voice-web projects (see **`DOCKER.md`**).

---

## Definition of done (POC)

- [ ] **External information:** Web search (Open WebUI) **or** saved page text via `scripts/fetch_url.py` into the sandbox.
- [ ] **One local model:** Same Ollama model for research UI and Open Interpreter (e.g. `llama3.1:8b` or `gemma2:9b`).
- [ ] **Local actions (sandbox):** Files/shell only under **`~/vap-sandbox-0`** (or a path you explicitly allow)—via **Phase 4** (WebUI → tools/API) **and/or** **Phase 3** (Interpreter). **No** silent auto-run until you trust the flow.

---

## Phase 1 — Baseline (Ollama) — **all required**

Nothing in this phase is optional. Finish everything here before Phase 2.

- [ ] **Ollama CLI:** `ollama --version` runs (you may see MLX warnings on stderr; **`./scripts/start-poc.sh`** starts **`ollama serve`** via **`scripts/ollama-serve-bg.sh`** when the macOS app is missing).
- [ ] **Ollama API:** `curl -s http://127.0.0.1:11434/api/tags` returns **HTTP 200** and JSON with at least one **`models`** entry.
- [ ] **Models:** Pull or build what you need for WebUI + Interpreter (e.g. **`qwen2.5:0.5b`**, **`codellama`**). Custom **`node-0`**: **`ollama create node-0 -f reference/modelfiles/node-0`** (after **`ollama pull qwen2.5:0.5b`**). **`GET /api/tags`** lists whatever you have pulled or created.
- [ ] **asdf (if you use it):** **`./scripts/setup-phase3-asdf.sh`** writes **`.tool-versions`** in this folder (python / poetry / ollama); run **`asdf install`** from here. Use **standard CPython 3.12.x** (repo pins **3.12.3**) for **`poetry install`**—avoid **3.14** and **`*t`** (free-threaded) builds.
- [ ] **Sandbox directory:** **`~/vap-sandbox-0`** exists (`mkdir -p ~/vap-sandbox-0`) — **outside** this project tree. (Later you may widen scope to **`$HOME`**.)

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

### Bring up WebUI (Docker + Ollama)

- [ ] From **`projects/local-ai`**: **`./scripts/start-poc.sh`** — starts **OrbStack** / **Docker** and **Ollama** if they are not already up, then **`docker compose up -d`**. Stop the stack with **`./scripts/stop-poc.sh`** (Ollama/OrbStack keep running). See **`DOCKER.md`** for env overrides (`LOCAL_AI_SKIP_ORB_START`, etc.).
- [ ] Or start **OrbStack** + **Ollama** yourself, then **`docker compose up -d`** in this folder.

Pick **one** path for the POC (add others later):

| Path | When to use |
|------|-------------|
| **A. Open WebUI + Web Search** | You want UI + RAG + search; configure a backend in admin settings (see main README). |
| **B. Manual** | Fastest: copy/paste or download into sandbox, chat in WebUI over files. |
| **C. `scripts/fetch_url.py`** | Fetch a URL to a text file in the sandbox, then point the model at that file. |

- [ ] **A:** WebUI reachable at **http://localhost:3000**; models visible; web search enabled if desired.
- [ ] **Admin:** **`cp .env.example .env`**, set **`WEBUI_ADMIN_*`**, then **`docker compose up -d --force-recreate open-webui`** (or **`./scripts/start-poc.sh`**) so the first user is created without the wizard — see **`DOCKER.md` §4**. Data survives **`docker compose down`**; use **`down -v`** only for a full reset.
- [ ] **B:** At least one real note/file in sandbox used in a chat.
- [ ] **C:** `python3 scripts/fetch_url.py https://example.com -o ~/vap-sandbox-0/page.html` (from `projects/local-ai`).

### Host Ollama (for WebUI)

Compose should point **`OLLAMA_BASE_URL`** at **host** Ollama (e.g. **`http://host.docker.internal:11434`** on macOS OrbStack). **No** second Ollama service in **`docker-compose.yml`**. If models in WebUI match **`ollama list`** on the host, this is already correct.

---

## Phase 3 — Action leg (Open Interpreter) — **optional**

Use this **or** focus on **Phase 4** for “do things on disk” from the browser.

- [ ] **asdf:** Plugins **python**, **poetry**, and **ollama** installed (`asdf plugin list`).
- [ ] From **`projects/local-ai`**: **`./scripts/setup-phase3-asdf.sh`** — writes **`.tool-versions`** (**python** prefers **3.12.x**, then **3.13.x**; plus **poetry** / **ollama**) and runs **`asdf install`**.
- [ ] **`poetry install`** — installs **`open-interpreter`** from **`pyproject.toml`** / **`poetry.lock`**.
- [ ] **`cd` into `~/vap-sandbox-0`** → **`poetry -C /path/to/local-ai run interpreter --model ollama/<same-model-as-ollama-pull>`** (Poetry **1.2+**; use the absolute path to **this** folder).
- [ ] Single scripted task works (e.g. “add a function to `hello.py` and update `notes.md`”).
- [ ] Confirm-before-run stays on until you are comfortable.

---

## Phase 4 — Tooling / API integrations (local orchestration from Open WebUI)

**Detailed plan (resume here):** **[docs/phase-4-plan.md](docs/phase-4-plan.md)**

**Goal:** From **Open WebUI**, the model can **trigger real actions on your machine** (e.g. list a directory under your sandbox), and the **chat shows both** the tool call and the **result**—not just a text guess. Vanilla chat + Ollama does **not** see your disk; this phase is the **glue** (tools, functions, or a small local API) you implement.

**Yes, it is possible** with extra setup. Typical shape:

1. **Allow-listed operations** — e.g. `list_dir`, `read_file`, `write_file` restricted to **`~/vap-sandbox-0`** (or another fixed root). Avoid arbitrary shell unless you add explicit confirmation.
2. **Local executor service** — small **HTTP API on the host** (e.g. FastAPI/Flask) that performs those operations. Open WebUI (in Docker) calls **`http://host.docker.internal:<port>/...`** (macOS) or your LAN IP on Linux.
3. **Wire WebUI to the API** — use your Open WebUI version’s **Tools / Functions / OpenAPI actions** (names change by release) so the model can invoke those endpoints; follow current **Open WebUI** docs for your image tag.
4. **Model behavior** — tool-capable models and prompts/templates that actually **emit tool calls** your integration understands (small models often struggle; expect iteration).

**Checklist**

- [ ] Write down **allowed actions** and **root directory** (start with sandbox only).
- [ ] Implement the **local executor** in this repo (e.g. under **`scripts/`** or a new **`executor/`** package) with **auth** (shared secret header) and **input validation** (no `..`, no paths outside root).
- [ ] Expose it on a fixed **port**; document how Docker reaches the host (**`host.docker.internal`** vs Linux).
- [ ] Register the tool/OpenAPI integration in **Open WebUI** admin and test with **curl** before relying on the model.
- [ ] **End-to-end:** From WebUI, a prompt like “list files in my sandbox” results in an **executed** action and the **listing** (or clear error) in the thread.
- [ ] **Hardening:** Rate limits, logging, and a policy for **write/execute** vs read-only until you trust the loop.

---

## Phase 5 — Hardening (after POC)

- [ ] Pin WebUI image tag (not only `:main`) if you want reproducible deploys.
- [ ] Document your **exact** model name in this file or a local `MODEL.txt` in sandbox.
- [ ] Optional: self-hosted **SearXNG** for web search without commercial APIs.
- [ ] Optional: run Interpreter in Docker with **only** sandbox mounted.

---

## Quick commands (from this directory)

```bash
# Phase 2 — OrbStack + Ollama + compose (macOS-friendly)
./scripts/start-poc.sh
./scripts/stop-poc.sh

# WebUI only (if Docker + Ollama already running)
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

Today, **`verify-phase1.sh`** is the first verify hook; **`start-poc.sh`** / **`stop-poc.sh`** automate **Phase 2**; **`setup-phase3-asdf.sh`** pins asdf runtimes for **Phase 3**. Later, add **`verify-phase2.sh`**, **`verify-phase3.sh`**, **`verify-phase4.sh`** (local executor reachable + optional tool smoke), … or one orchestrator that calls phase scripts and gates on each exit code. The POC checklist above stays the **spec**; the scripts become the **automation**.

When you add automation, link the entrypoint here and keep **manual** steps documented for debugging.
