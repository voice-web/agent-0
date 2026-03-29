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
