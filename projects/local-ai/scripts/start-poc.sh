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

# True if something is listening on 11434 (macOS / Linux).
ollama_port_listening() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:11434 -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi
  # Fallback: bash /dev/tcp (no extra deps)
  (echo >/dev/tcp/127.0.0.1/11434) >/dev/null 2>&1
}

# Start `ollama serve` when the GUI app is missing (common with Homebrew / asdf ollama).
# Logs only under ${ROOT}/var/ (no dependency on paths outside this project).
try_start_ollama_cli() {
  command -v ollama >/dev/null 2>&1 || return 1
  if pgrep -f '[o]llama serve' >/dev/null 2>&1; then
    say "Found existing \`ollama serve\` process; waiting for API…"
    return 0
  fi
  if ollama_port_listening; then
    return 0
  fi
  say "Nothing on :11434 — starting Ollama via CLI (\`scripts/ollama-serve-bg.sh\`). Log: ${ROOT}/var/ollama-serve.log"
  bash "${ROOT}/scripts/ollama-serve-bg.sh"
  sleep 2
  return 0
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

  say "Ollama not responding on :11434; trying to start…"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # Official app (if installed); no-op for CLI-only Homebrew/asdf installs.
    open -a Ollama 2>/dev/null || true
  fi

  local waited=0
  local tried_cli=0
  while ! ollama_ok; do
    # After ~10s, if nothing is listening on 11434, start `ollama serve` (CLI install path).
    if (( waited >= 10 && tried_cli == 0 )); then
      if ! ollama_port_listening; then
        try_start_ollama_cli || true
      fi
      tried_cli=1
    fi

    if (( waited >= 90 )); then
      echo "error: Ollama did not become ready at ${OLLAMA_URL} (after ${waited}s)." >&2
      echo "    macOS: install the Ollama app, or ensure \`ollama\` is on PATH and run: ollama serve" >&2
      echo "    Linux: ollama serve   or: sudo systemctl start ollama" >&2
      echo "    Log (if CLI fallback ran): ${ROOT}/var/ollama-serve.log" >&2
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
    echo "    … waiting for Ollama (${waited}s)"
  done
  say "Ollama is up."
}

# First boot after pull can take 30–120s+ before uvicorn listens; HTTP 000 = nothing on the port yet.
wait_for_webui() {
  local max="${LOCAL_AI_WEBUI_WAIT_SECS:-180}"
  local t=0
  local code="000"
  say "Waiting for Open WebUI on ${WEBUI_URL} (up to ${max}s; first start is slow)…"
  while (( t < max )); do
    code="000"
    c="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 8 "${WEBUI_URL}/" 2>/dev/null)" && code="$c"
    [[ -z "$code" ]] && code="000"
    if [[ "$code" =~ ^(200|301|302|303|307|308)$ ]]; then
      say "WebUI answered HTTP ${code} at ${WEBUI_URL} (after ${t}s)"
      return 0
    fi
    sleep 3
    t=$((t + 3))
    if (( t % 15 == 0 )); then
      echo "    … still waiting for TCP ${WEBUI_PORT} (${t}s, last HTTP ${code})"
    fi
  done

  echo "error: WebUI did not respond on ${WEBUI_URL} after ${max}s (last HTTP ${code})." >&2
  echo "    Try in browser anyway; if it fails, check OrbStack port forwarding and logs below." >&2
  echo "---- docker compose ps ----" >&2
  docker compose ps -a >&2 || true
  echo "---- docker compose logs (last 50 lines, service open-webui) ----" >&2
  docker compose logs --tail 50 open-webui >&2 || true
  return 1
}

say "local-ai Phase 2 — project dir: ${ROOT}"
ensure_docker
ensure_ollama

say "docker compose up -d …"
docker compose up -d

say "compose stack started (container: open-webui)."
if ! wait_for_webui; then
  echo "" >&2
  echo "    Tip: re-run after a minute, or: cd ${ROOT} && docker compose logs -f open-webui" >&2
  exit 1
fi

echo ""
echo "    Open WebUI: ${WEBUI_URL}"
echo "    Ollama API:   ${OLLAMA_URL}"
echo "    Stop stack:   ${ROOT}/scripts/stop-poc.sh"
if [[ -f "${ROOT}/.env" ]] && grep -qE '^WEBUI_ADMIN_EMAIL=.+' "${ROOT}/.env" 2>/dev/null && grep -qE '^WEBUI_ADMIN_PASSWORD=.+' "${ROOT}/.env" 2>/dev/null; then
  echo "    Headless admin: configured in .env (applied only when the DB has **no users** yet)."
else
  echo "    Admin account: copy .env.example → .env and set WEBUI_ADMIN_* for auto-admin on **fresh** volumes, or sign up in the UI."
  echo "                   API fallback: ./scripts/create-webui-admin-api.sh (after WebUI is up)."
fi
