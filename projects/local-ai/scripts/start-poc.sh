#!/usr/bin/env bash
# Phase 2 — bring up Open WebUI POC: Docker (OrbStack) + Ollama on host + docker compose.
# Run from anywhere:  projects/local-ai/scripts/start-poc.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WEBUI_PORT="${LOCAL_AI_WEBUI_PORT:-3000}"
OLLAMA_URL="${LOCAL_AI_OLLAMA_URL:-http://127.0.0.1:11434}"
WEBUI_URL="http://127.0.0.1:${WEBUI_PORT}"

say() { echo "==> $*"; }

docker_ok() {
  docker info >/dev/null 2>&1
}

ollama_ok() {
  curl -sf --connect-timeout 2 --max-time 5 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1
}

ensure_docker() {
  if docker_ok; then
    say "Docker engine already reachable."
    return 0
  fi

  if [[ "${LOCAL_AI_SKIP_ORB_START:-}" == "1" ]]; then
    echo "error: Docker not running and LOCAL_AI_SKIP_ORB_START=1 (start OrbStack / Docker Desktop manually)." >&2
    exit 1
  fi

  say "Docker not reachable; trying to start OrbStack…"
  if command -v orb >/dev/null 2>&1; then
    orb start 2>/dev/null || true
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    open -a OrbStack 2>/dev/null || {
      echo "error: could not run 'open -a OrbStack'. Install OrbStack or set Docker running." >&2
      exit 1
    }
  else
    echo "error: Docker not running. Start your Docker engine (Linux: Docker Engine / compose plugin)." >&2
    exit 1
  fi

  local waited=0
  while ! docker_ok; do
    if (( waited >= 90 )); then
      echo "error: Docker still not reachable after ${waited}s." >&2
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
    echo "    … waiting for Docker (${waited}s)"
  done
  say "Docker engine is up."
}

ensure_ollama() {
  if ollama_ok; then
    say "Ollama already responding on ${OLLAMA_URL}."
    return 0
  fi

  if [[ "${LOCAL_AI_SKIP_OLLAMA_START:-}" == "1" ]]; then
    echo "error: Ollama not responding and LOCAL_AI_SKIP_OLLAMA_START=1." >&2
    exit 1
  fi

  say "Ollama not responding on :11434; trying to start (macOS: Ollama app)…"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    open -a Ollama 2>/dev/null || true
  elif command -v ollama >/dev/null 2>&1; then
    # Linux: one attempt — user may already use systemd; avoid duplicate servers
    if ! pgrep -x ollama >/dev/null 2>&1; then
      echo "    hint: start Ollama with: ollama serve   or: sudo systemctl start ollama" >&2
    fi
  fi

  local waited=0
  while ! ollama_ok; do
    if (( waited >= 90 )); then
      echo "error: Ollama did not become ready at ${OLLAMA_URL} (after ${waited}s)." >&2
      echo "    Start it manually (macOS: Ollama app; Linux: ollama serve / systemctl)." >&2
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
    echo "    … waiting for Ollama (${waited}s)"
  done
  say "Ollama is up."
}

verify_webui_http() {
  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 10 "${WEBUI_URL}/" || true)"
  if [[ "$code" =~ ^(200|301|302|303|307|308)$ ]]; then
    say "WebUI answered HTTP ${code} at ${WEBUI_URL}"
    return 0
  fi
  echo "warn: WebUI check got HTTP ${code:-000} (container may still be starting); open ${WEBUI_URL} in a browser." >&2
}

say "local-ai Phase 2 — project dir: ${ROOT}"
ensure_docker
ensure_ollama

say "docker compose up -d …"
docker compose up -d

say "compose stack started (container: open-webui)."
sleep 2
verify_webui_http || true

echo ""
echo "    Open WebUI: ${WEBUI_URL}"
echo "    Ollama API:   ${OLLAMA_URL}"
echo "    Stop stack:   ${ROOT}/scripts/stop-poc.sh"
