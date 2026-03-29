# agent-0

Workspace for local AI and related experiments. Work is organized under **`projects/`**.

| Project | Purpose |
|---------|---------|
| [**projects/ollama**](projects/ollama/) | Reference docs (Ollama, Colima, tool-use, RAG/dev surveys), helper **scripts**, and **custom-models**. Lifted here from the old flat repo layout. |
| [**projects/local-ai**](projects/local-ai/) | Private stack POC: Ollama + Open WebUI (Docker), Open Interpreter, sandbox workflow—see that README and **POC.md**. |

The **`.seed`** symlink at the repo root (if present) points at shared seed content from **abeja-reina** for Cursor prompts.

**Sandbox (local-ai / Open Interpreter):** **`~/vap-sandbox-0`** — working directory **outside** this repo (create with `mkdir -p ~/vap-sandbox-0`). Later you may widen scope to your full home directory; see **`projects/local-ai/README.md`**.

**asdf:** **`.tool-versions`** at the repo root pins **`ollama 0.17.0`** (same pin as **`projects/ollama/.tool-versions`**) so `asdf` can select that Ollama build when you work from the repo root.
