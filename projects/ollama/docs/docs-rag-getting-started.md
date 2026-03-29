# Getting started: Docs & RAG

Tools in this category focus on **documents and retrieval-augmented generation (RAG)**—feeding the model your own files, PDFs, or sites so it can answer from a private knowledge base.

---

## AnythingLLM

**Best for:** Chatting with your PDFs and building a private knowledge base.

- **What it is:** Full-stack app for RAG. Ingest folders of PDFs or websites; it builds a searchable knowledge base and lets the model cite those sources.
- **Getting started:**
  1. Download from [anythingllm.com](https://useanything.com) (or GitHub releases).
  2. Install and launch (desktop app or Docker).
  3. Create a workspace, add a document source (folder, PDFs, or URLs).
  4. Wait for indexing, then chat; the model will use your docs as context.
- **Tip:** Start with a small folder of PDFs to test before adding large corpora.

---

## Open WebUI

**Best for:** A ChatGPT-like interface in the browser, with Ollama as the engine.

- **What it is:** Open-source web frontend that talks to Ollama. Gives you a polished chat UI, model selection, and optional RAG/plugins while Ollama runs the models locally.
- **Getting started:**
  1. Install and run **Ollama** first ([ollama.com](https://ollama.com)); pull a model (e.g. `ollama pull llama3.2`).
  2. Install Open WebUI (Docker is common: `docker run -d -p 3000:8080 ...` — see [Open WebUI docs](https://docs.openwebui.com)).
  3. Open `http://localhost:3000` in your browser.
  4. Connect to your local Ollama; select a model and start chatting.
- **Tip:** Use it when you want a nice UI without leaving the terminal for Ollama’s CLI.

---

## Quick comparison

| Tool        | Best for              | Setup complexity |
|------------|------------------------|------------------|
| AnythingLLM | PDFs, folders, RAG    | Medium           |
| Open WebUI  | Chat UI on top of Ollama | Low (if Ollama already installed) |

Both can coexist: use Ollama + Open WebUI for general chat, and AnythingLLM when you need to query your own documents.
