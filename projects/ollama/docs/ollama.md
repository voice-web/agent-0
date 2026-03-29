# Ollama quick start guide

## 1. Core commands

| Command | Description |
|--------|-------------|
| `ollama serve` | Start the API server (runs on port 11434). |
| `ollama run <model_name>` | Run a model; downloads automatically if missing. |
| `ollama pull <model_name>` | Download only (e.g. pre-load before going offline). |
| `ollama list` | List local models. |
| `ollama ps` | Show running models. |

## 2. Recommended small models (< 2.5GB)

| Model | Size | Best for |
|-------|------|----------|
| qwen2.5:0.5b | ~400MB | Ultra-fast, basic logic, low RAM. |
| qwen2.5:1.5b | ~1GB | Balanced speed and intelligence. |
| llama3.2:1b | ~1.3GB | High-quality general chat. |
| llama3.2:3b | ~2GB | More complex reasoning. |

## 3. Managing the engine

- **Stop foreground server:** `Ctrl+C` in the terminal where `ollama serve` is running.
- **Exit chat:** Type `/bye` or `Ctrl+D`.
- **Force stop (all):** `pkill ollama`.

## 4. Background running

- **Mac/Windows:** Use the Ollama desktop app; it runs from the menu bar / system tray.
- **Manual background (Linux/macOS):** `nohup ollama serve > ollama.log 2>&1 &`
- **Linux service:** `sudo systemctl start ollama`

## 5. Creating a custom small model

Create a file named `Modelfile` with:

```modelfile
FROM llama3.2:1b
SYSTEM "You are a minimalist assistant. Answer in one sentence."
PARAMETER temperature 0.1
```

Then build and run:

```bash
ollama create my-model -f Modelfile
ollama run my-model
```

## 6. Open WebUI (browser UI for all your models)

Open WebUI gives you a ChatGPT-style interface in the browser and lets you pick which Ollama model to chat with. Run it in Docker and connect it to your local Ollama server.

**Prerequisites**

- Docker installed and running.
- Ollama running on the host (e.g. `ollama serve` or `projects/ollama/scripts/ollama-bg` from the repo root, or `./scripts/ollama-bg` from `projects/ollama`).

**Run Open WebUI in Docker**

```bash
docker run -d -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

- **Port:** Open WebUI is at **http://localhost:3000**.
- **Data:** `-v open-webui:/app/backend/data` keeps chats and settings across restarts.
- **Host Ollama:** `--add-host=host.docker.internal:host-gateway` lets the container reach Ollama on your machine.

**Connect to Ollama**

1. Open http://localhost:3000 and complete the first-time setup (create an admin user).
2. In the UI, go to **Settings** (or the connection/API section) and set the Ollama URL to:
   - **http://host.docker.internal:11434** (Mac/Windows; so the container can reach Ollama on the host).
3. Your local models will appear in the model selector; pick one and chat.

**Stop and remove**

```bash
docker stop open-webui
docker rm open-webui
# Data in volume open-webui is kept; remove with: docker volume rm open-webui
```
