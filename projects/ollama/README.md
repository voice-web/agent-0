# ollama (reference bundle)

This folder holds the **previous root-level** material from **agent-0**: notes, scripts, and small Modelfiles. It is **not** a separate git repo—use it as **reference** while you work in **`projects/local-ai`** or elsewhere.

## Contents

| Path | What |
|------|------|
| **`docs/`** | Ollama quick start, Colima, tool-use / function calling, getting-started comparisons (RAG, dev speed), session note `2026.02.26.md`. |
| **`scripts/`** | `ollama-bg` / `ollama-kill`, macOS `system-resources` CLI, `usage-monitor` + LaunchAgent plist. |
| **`custom-models/`** | Example **Modelfile**-style file `node-0` (`ollama create … -f custom-models/node-0`). |
| **`.tool-versions`** | asdf pin for Ollama (use from this directory: `cd` here before `asdf` commands if you rely on it). |

## Paths in the docs

Install snippets that used “repo root” assume you are in **`projects/ollama`** (e.g. `$(pwd)/scripts/usage-monitor`). From the **agent-0** root, prefix with `projects/ollama/`.

## Docker (Open WebUI)

For **Open WebUI + Compose** and the full private-stack guide, use **`../local-ai/`** instead of duplicating containers from **`docs/ollama.md`**.

---

## What shows up in `GET /api/tags` (models on this machine)

If **`curl -s http://127.0.0.1:11434/api/tags`** lists something like the following, it matches how this repo was used in **Feb 2026**:

| Model tag | What it is | How it got there |
|-----------|------------|------------------|
| **`node-0:latest`** | Custom model: **qwen2.5:0.5b** + system prompt and low temperature (see file below). | Built from the repo: `cd projects/ollama && ollama create node-0 -f custom-models/node-0` (after `ollama pull qwen2.5:0.5b`). |
| **`qwen2.5:0.5b`** | Stock library model (~0.5B params, **Q4_K_M** in your listing). | `ollama pull qwen2.5:0.5b` — also the **parent** for `node-0`. |
| **`codellama:latest`** | Code-focused **Llama** variant (your listing: **7B**, **Q4_0**, ~3.8GB). | **Not** defined in this repo; installed with e.g. `ollama pull codellama` (tag may show as `codellama:latest`). |

The **Modelfile** for **`node-0`** is **`custom-models/node-0`** in this folder:

```modelfile
FROM qwen2.5:0.5b
SYSTEM "You are a minimalist assistant. Answer in one sentence and always ask 'What can I do for you master?'"
PARAMETER temperature 0.1
```

To **rebuild** `node-0` after editing that file: run `ollama create node-0 -f custom-models/node-0` again from **`projects/ollama`**.

**Tooling:** **`.tool-versions`** here pins **`ollama 0.17.0`** for **asdf**. A copy at the **agent-0 repo root** keeps the same pin when you run asdf from the root.
