# Open WebUI POC with **Docker Compose** (macOS: **OrbStack**)

This matches how other **voice-web** repos run local Docker POCs (e.g. **`vap`** → `projects/local-gateway-v1`): **OrbStack** on the Mac provides the Docker engine; **`docker compose`** starts **Open WebUI** from **`docker-compose.yml`**.

**OrbStack** is a Docker-compatible runtime on macOS. Install from [orbstack.dev](https://orbstack.dev/) and keep the **OrbStack** app running when you use containers. The **`docker`** CLI behaves like Linux; **`host.docker.internal`** reaches the Mac host (where **Ollama** should listen on **11434**).

Docker Desktop, Rancher, or a remote Docker host also work; this doc assumes **OrbStack** on macOS.

---

## 1. OrbStack running + Docker context

1. Open **OrbStack** and ensure Docker is **running** (menu bar icon).
2. Verify the CLI:

```bash
docker info
docker context ls
```

Use the **`orbstack`** context if prompted (often the default after install).

---

## 2. Ollama on the host (not in the container)

Start **Ollama** on the Mac so it binds to **127.0.0.1:11434** (default). The WebUI container calls **`http://host.docker.internal:11434`**.

```bash
curl -s http://127.0.0.1:11434/api/tags
```

---

## 3. Compose: start Open WebUI

### Scripted (Phase 2) — recommended on macOS

From **`projects/local-ai/`**:

```bash
./scripts/start-poc.sh
```

This tries to start **OrbStack** (`orb start` or `open -a OrbStack`) and the **Ollama** app if needed, waits until **Docker** and **`/api/tags`** respond, then runs **`docker compose up -d`**.

```bash
./scripts/stop-poc.sh
```

Stops only the **compose** stack (**`docker compose down`**). **Ollama** and **OrbStack** stay running.

**Environment (optional):**

| Variable | Effect |
|----------|--------|
| `LOCAL_AI_SKIP_ORB_START=1` | Do not try to launch OrbStack; fail if Docker is down. |
| `LOCAL_AI_SKIP_OLLAMA_START=1` | Do not try to open the Ollama app; fail if Ollama is down. |
| `LOCAL_AI_WEBUI_PORT=3000` | Port check base URL (default **3000**). |

### Manual

From **`projects/local-ai/`** (this folder):

```bash
docker compose up -d
```

Open **http://localhost:3000**, complete first-time admin setup, then chat using your pulled Ollama models.

**Stop / remove** (keeps the named volume `open-webui` with WebUI data):

```bash
docker compose down
```

**Logs:**

```bash
docker compose logs -f open-webui
```

---

## 4. `docker compose` vs `docker-compose`

- **Compose v2 (plugin):** `docker compose` (space) — preferred.
- **Compose v1 (standalone):** `docker-compose` (hyphen) — use if `docker compose` is missing.

```bash
docker compose version
```

---

## 5. Linux / other engines

On **Linux** Docker Engine, **`host.docker.internal`** may be undefined. See the main **[README.md](README.md)** Part 2 (host network or bridge IP). **OrbStack** is macOS-focused; on Linux use your distro’s Docker and those notes.
