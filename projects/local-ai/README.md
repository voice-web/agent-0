# local-ai

Private, local AI workstation: **research** (Open WebUI + RAG + web search), **action** (Open Interpreter + local files/code), and a **single local model host** (Ollama). Goal: iterate on a business idea **without sending prompts or documents to the cloud**.

**Repository:** This project lives under **`agent-0`** at `projects/local-ai/`. It was removed from the **`vap`** repo to keep all implementation and POC work here. Older notes and host scripts live next door in **`../ollama/`** (reference bundle).

**POC roadmap:** Step-by-step phases, checkboxes, and definition of done → **[POC.md](POC.md)**.

**Ollama:** If you already installed Ollama and pulled models on this machine, treat **Part 1** as verification only and start from **POC.md** Phase 2–3 or **Part 2** below.

**Quick start (WebUI + host Ollama):** On **macOS**, run **OrbStack**, start **Ollama** on the host, then from this directory:

```bash
docker compose up -d
```

Open **http://localhost:3000**. Step-by-step for **OrbStack**, context checks, and **`docker compose` vs `docker-compose`**: **[DOCKER.md](DOCKER.md)** (same POC style as **`vap`** projects such as **`local-gateway-v1`**). On **Linux** Docker Engine, read **Part 2** for `host.docker.internal` vs bridge IP / host network.

**URL → file (no search setup):** `python3 scripts/fetch_url.py <url> -o ~/vap-sandbox-0/page.html` (run from `projects/local-ai`, or pass any absolute path).

---

## What you are building

| Layer | Role |
|--------|------|
| **Engine** | Ollama serves models on your machine (default API: `http://127.0.0.1:11434`). |
| **Research hub** | Open WebUI (Docker) for chat, documents/RAG, and optional web search—still using **your** Ollama. |
| **Action agent** | Open Interpreter uses the **same** Ollama models to propose and run code; you control execution. |
| **Bridge** | Both clients point at the **same** Ollama base URL; pull each model once with `ollama pull …`. |

---

## Hardware (smooth experience)

These are **practical** targets for **Gemma 2 9B** or **Llama 3.1 8B** at **4-bit quantizations** (typical Ollama defaults), moderate context, and room for the OS + browser + Docker.

| Profile | GPU / accelerator | System RAM | Notes |
|---------|-------------------|------------|--------|
| **Comfortable** | **16 GB+ VRAM** (NVIDIA) or **24 GB+** unified (Apple M-series) | **32 GB+** | Fewer OOMs, snappier context, WebUI + Docker overhead covered. |
| **Minimum (tight)** | **8 GB VRAM** or strong **CPU** offload | **16 GB** | Use smaller quants, shorter context, close heavy apps; first load can be slow. |

**CPU-only** is possible but much slower; prefer a **GPU** or **Apple Silicon** for daily use.

---

## Part 1 — The engine: install Ollama

Install **one** Ollama on the **host** (not inside the WebUI container). Keep it running while you use WebUI and Open Interpreter.

### macOS

**Option A — official installer**  
Download and install from [ollama.com/download](https://ollama.com/download).

**Option B — Homebrew**

```bash
brew install ollama
brew services start ollama
```

### Linux

```bash
curl -fsSL https://ollama.com/install.sh | sh
# Often enabled automatically; if not:
sudo systemctl enable --now ollama
```

Confirm:

```bash
ollama --version
curl -s http://127.0.0.1:11434/api/tags
```

### Windows (PowerShell)

1. Install from [ollama.com/download](https://ollama.com/download) (recommended), **or** use **winget** if available:

```powershell
winget install Ollama.Ollama
```

2. Start **Ollama** from the Start menu if it does not auto-start.

3. In **PowerShell**:

```powershell
ollama --version
curl http://127.0.0.1:11434/api/tags
```

### Pull shared models (once per model)

Use the **same** tags in WebUI and Open Interpreter:

```bash
ollama pull gemma2:9b
# or
ollama pull llama3.1:8b
```

---

## Part 2 — Research hub: Open WebUI (Docker / Compose)

Open WebUI needs to reach Ollama on the **host**. The usual pattern is `OLLAMA_BASE_URL` pointing at the host from inside the container.

### macOS POC: OrbStack + Compose (recommended)

1. Start **OrbStack** and confirm **`docker info`** works — see **[DOCKER.md](DOCKER.md)**.
2. Run **Ollama** on the Mac (host), not inside the WebUI container.
3. From `projects/local-ai/`:

```bash
docker compose up -d
```

This uses **`docker-compose.yml`**: `OLLAMA_BASE_URL=http://host.docker.internal:11434`, port **3000** on the host. OrbStack resolves **`host.docker.internal`** to your Mac like Docker Desktop.

Open **http://localhost:3000**, create the **first** admin account, then sign in.

### Compose without OrbStack

**Docker Desktop** (macOS/Windows) or another engine that supports **`host.docker.internal`**: same **`docker compose up -d`** and the same compose file usually work. **Linux:** see below; you may need a different `OLLAMA_BASE_URL` or network mode.

### Alternative — `docker run` (OrbStack / Docker Desktop)

`host.docker.internal` resolves to the host. **Include** `--add-host` (or `extra_hosts` in Compose) so the container can reach it.

```bash
docker volume create open-webui

docker run -d \
  --name open-webui \
  --restart unless-stopped \
  -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
```

Open **http://localhost:3000**, create the **first** admin account, then sign in.

### Linux (Docker Engine)

`host.docker.internal` is **not** always defined. Pick **one** approach:

**A — Host network** (simple; WebUI listens on host port **8080** in many images—check container logs if 3000 mapping differs):

```bash
docker volume create open-webui

docker run -d \
  --name open-webui \
  --restart unless-stopped \
  --network host \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
```

**B — Bridge network + Docker bridge IP** (if you use `-p` publishing):

```bash
docker volume create open-webui

docker run -d \
  --name open-webui \
  --restart unless-stopped \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://172.17.0.1:11434 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
```

If `172.17.0.1` does not work on your distro, run `ip -4 addr show docker0` (or inspect your bridge gateway) and substitute that IP.

### Enable **Web Search** in Open WebUI

UI labels move between releases; the idea is always: **admin → settings → feature / web search**.

1. Sign in as an **admin** user.
2. Open **Settings** (gear / admin panel).
3. Find **Features** or **Web Search** (sometimes under **Connections** / **Integrations**).
4. Enable **Web Search**.
5. Choose a **search backend** (e.g. **SearXNG**, **Google Programmable Search**, **Brave**, etc.) and paste the **API key** or **base URL** that backend requires.

**Privacy note:** web search sends **queries** to whichever search provider you configure—it is not the same as sending chat to OpenAI. For maximum privacy, run a **local SearXNG** instance and point WebUI at it.

**RAG / documents:** use Open WebUI’s **Knowledge** / **Documents** / **Collections** UI to upload or index files; retrieval stays on your machine (subject to how you configured storage and search).

---

## Part 3 — Action agent: Open Interpreter

Use a **virtual environment** so dependencies stay isolated.

### macOS / Linux

```bash
python3 -m venv ~/.venvs/open-interpreter
source ~/.venvs/open-interpreter/bin/activate
pip install -U pip open-interpreter
```

### Windows (PowerShell)

```powershell
python -m venv $env:USERPROFILE\.venvs\open-interpreter
& $env:USERPROFILE\.venvs\open-interpreter\Scripts\Activate.ps1
pip install -U pip open-interpreter
```

### Point Open Interpreter at **local Ollama**

With Ollama running on the host:

```bash
interpreter --model ollama/llama3.1:8b
# or
interpreter --model ollama/gemma2:9b
```

If your install expects the chat variant, try `ollama_chat/<model>` instead of `ollama/<model>` (see [Open Interpreter local models](https://docs.openinterpreter.com/language-models/local-models)).

**Interactive local setup:**

```bash
interpreter --local
```

Follow prompts to select **Ollama** and the model name that matches what you pulled.

---

## Part 4 — The bridge (one Ollama, two clients)

| Client | Where it runs | Ollama URL you configure |
|--------|----------------|---------------------------|
| **Ollama** | Host | `http://127.0.0.1:11434` (default) |
| **Open WebUI** | Docker container | `http://host.docker.internal:11434` (macOS **OrbStack** / Docker Desktop, Windows) or `http://127.0.0.1:11434` / `http://172.17.0.1:11434` (Linux—see above) |
| **Open Interpreter** | Host (venv) | Default `http://localhost:11434` when using `ollama/...` |

**Rules of thumb:**

- Do **not** append `/api` to `OLLAMA_BASE_URL` for Open WebUI unless your release notes say otherwise.
- After changing `OLLAMA_BASE_URL`, **recreate** the container: `docker rm -f open-webui` and run `docker run …` again (or update Compose and `docker compose up -d`).

---

## Part 5 — Security & workspace (“sandbox” folder)

Open Interpreter can **read and execute** on the machine where it runs. A **dedicated folder** is a **policy + habit** layer; it is **not** a hard kernel-enforced jail unless you add more isolation.

### Recommended baseline

1. **Default sandbox (outside the repo):** **`~/vap-sandbox-0`**. Create it once: `mkdir -p ~/vap-sandbox-0`. Keeping agent file work **outside** **agent-0** avoids mixing generated content with git-tracked code. For this POC the folder name is fixed; **later** you can treat **`$HOME`** as the workspace if you choose (understanding the risk footprint).
2. **Always** activate your venv, **`cd` into the sandbox**, then start Interpreter:

   ```bash
   cd ~/vap-sandbox-0
   source ~/.venvs/open-interpreter/bin/activate
   interpreter --model ollama/qwen2.5:0.5b   # or node-0, codellama, llama3.1:8b, etc.
   ```

3. Keep **auto-run disabled** until you trust the workflow; approve actions when Interpreter asks.

4. **Optional stronger isolation:** run Open Interpreter inside **Docker** with **only** that directory bind-mounted as `/workspace`, and use Open Interpreter’s **sandbox / Docker** documentation for your version ([safety docs](https://docs.openinterpreter.com/safety/introduction)).

### Prompt rule (belt-and-suspenders)

Tell the model explicitly: *Only read/write under `~/vap-sandbox-0` (or expand to the absolute path); refuse paths outside it.*

---

## Safety check — telemetry and data sharing

Vendor UIs change; re-check each product’s **Settings → Privacy** and **docs** after upgrades.

| Tool | What to do |
|------|------------|
| **Ollama** | Ollama’s documented server knobs are things like `OLLAMA_HOST`, `OLLAMA_ORIGINS`, model paths—not a single “telemetry off” switch in public env docs. Treat **updates** and **network egress** as your control plane: run on a restricted network if you need hard assurances, and read the current [Ollama FAQ / privacy](https://github.com/ollama/ollama) for their latest statement. |
| **Open WebUI** | In **Admin Settings**, disable **usage / analytics** toggles if present; avoid external **OAuth** or **cloud sync** you do not want; keep **web search** pointed at **self-hosted** SearXNG if you want queries to stay internal. |
| **Open Interpreter** | Prefer **local** models only; avoid cloud API keys in profile; review [settings / privacy](https://docs.openinterpreter.com/) for your version. Disable any experimental features that call third parties. |
| **Docker** | For maximum offline behavior, use a **local registry mirror** or pin image digests; understand `docker pull` still contacts the registry you configured. |

---

## Quick verification checklist

- [ ] **macOS:** OrbStack is running and `docker info` succeeds (`docker context` → **orbstack** if applicable).
- [ ] `curl http://127.0.0.1:11434/api/tags` returns JSON on the host.
- [ ] Open WebUI shows your Ollama models and can chat.
- [ ] Open Interpreter responds using `ollama/<model>` without cloud API keys.
- [ ] Web search (if enabled) uses **your chosen** provider (self-hosted vs vendor).
- [ ] Interpreter is started only from **`~/vap-sandbox-0`** (or your chosen external directory).

---

## Troubleshooting

- **WebUI cannot see Ollama:** OrbStack or Docker engine not running; wrong `docker context`; wrong `OLLAMA_BASE_URL`; missing `extra_hosts` / `--add-host=host.docker.internal:host-gateway` in compose (this repo includes it); or on Linux wrong bridge IP—fix and `docker compose up -d --force-recreate` (or `docker compose down` then `up -d`).
- **Model not found:** run `ollama pull <name>` on the **host**; names must match in WebUI and Interpreter.
- **Out of memory:** smaller model, smaller context in WebUI/Interpreter, or close other GPU apps.

---

## References

- [OrbStack](https://orbstack.dev/) — Docker engine on macOS (POC with **`docker compose`** in this folder).
- [Ollama](https://ollama.com/) — install, models, API.
- [Open WebUI](https://github.com/open-webui/open-webui) — Docker, env vars, docs.
- [Open Interpreter](https://docs.openinterpreter.com/) — local / Ollama, safety, settings.

This document is a **living guide**; pin image tags and re-verify settings after major upgrades.
