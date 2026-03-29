# Getting started: Dev & speed

Tools in this category focus on **high performance and developer workflows**—APIs, throughput, and minimal setups for serving or integrating models.

---

## vLLM

**Best for:** Raw speed and high-throughput serving (multiple users, fast token generation).

- **What it is:** Inference engine optimized for throughput. Used when you need the fastest possible generation or to serve many concurrent requests.
- **Getting started:**
  1. Install: `pip install vllm` (Python 3.8+, GPU recommended).
  2. Serve a model: `python -m vllm.entrypoints.openai.api_server --model <model_name>` (e.g. a Hugging Face model ID).
  3. The server exposes an **OpenAI-compatible API** at `http://localhost:8000/v1` (or the port you set).
  4. Point your app or `curl` at that endpoint; use it like the OpenAI API.
- **Tip:** Check [vLLM docs](https://docs.vllm.ai) for supported models and GPU requirements.

---

## LocalAI

**Best for:** Drop-in replacement for the OpenAI API so existing apps run 100% locally with no code changes.

- **What it is:** Local server that mimics the OpenAI API. If your app uses `OPENAI_API_KEY` and `OPENAI_API_BASE`, point it at LocalAI and swap the base URL; the rest stays the same.
- **Getting started:**
  1. Install LocalAI (binary, Docker, or build from [GitHub](https://github.com/mudler/LocalAI)).
  2. Start the server and load a model (see LocalAI docs for model format and paths).
  3. Set in your app: `OPENAI_API_BASE=http://localhost:8080/v1` (or your LocalAI URL), and use any non-empty placeholder for the API key.
  4. Run your app; it will call LocalAI instead of OpenAI.
- **Tip:** Useful for Cursor, scripts, or any tool that already speaks the OpenAI API.

---

## llama.cpp

**Best for:** Lightweight, minimal, and portable—the foundation many other tools (including Ollama) build on.

- **What it is:** C++ inference runtime. No GPU required (CPU works); you run models via CLI or a simple server. Maximum control, minimal dependencies.
- **Getting started:**
  1. Clone and build: [github.com/ggerganov/llama.cpp](https://github.com/ggerganov/llama.cpp) — `cmake . && make` (or use prebuilt binaries).
  2. Download a GGUF model (e.g. from Hugging Face) and place it in the repo.
  3. Run: `./llama-cli -m your-model.gguf -p "Hello"` for interactive completion, or `./server` to start an HTTP API.
  4. The server exposes an OpenAI-compatible endpoint; point clients at it.
- **Tip:** Use when you want the smallest footprint or need to run on CPU-only or embedded systems.

---

## Quick comparison

| Tool       | Best for                    | Interface      |
|-----------|-----------------------------|----------------|
| vLLM      | Speed, multiple users       | CLI / API      |
| LocalAI   | Replacing OpenAI API       | API-focused    |
| llama.cpp | Minimal, portable, CPU     | CLI / server   |

All three expose or can expose an API; choose vLLM for max throughput, LocalAI for easiest OpenAI swap, and llama.cpp for minimal setup and portability.
