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
try_start_ollama_cli() {
  command -v ollama >/dev/null 2>&1 || return 1
  if pgrep -f '[o]llama serve' >/dev/null 2>&1; then
    say "Found existing \`ollama serve\` process; waiting for API…"
    return 0
  fi
  if ollama_port_listening; then
    return 0
  fi
  local log="${TMPDIR:-/tmp}/local-ai-ollama-serve.log"
  say "Nothing on :11434 — starting Ollama via CLI (\`ollama serve\`). Log: $log"
  # Same default as projects/ollama/scripts/ollama-bg (quiet MLX probe noise on some Mac builds).
  export OLLAMA_LLM_LIBRARY="${OLLAMA_LLM_LIBRARY:-cpu_avx2}"
  nohup ollama serve >>"$log" 2>&1 &
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
      echo "    Log (if CLI fallback ran): \${TMPDIR:-/tmp}/local-ai-ollama-serve.log" >&2
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
