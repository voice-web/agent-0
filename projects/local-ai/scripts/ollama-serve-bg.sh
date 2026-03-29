#!/usr/bin/env bash
# Background `ollama serve` with logs under this project only (portable tarball).
# Used by start-poc.sh when the macOS Ollama app is absent (CLI-only installs).
# Safe to run manually: ./scripts/ollama-serve-bg.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${ROOT}/var"
LOG="${ROOT}/var/ollama-serve.log"

if pgrep -f '[o]llama serve' >/dev/null 2>&1; then
  echo "ollama serve already running (log would be: $LOG)"
  exit 0
fi

export OLLAMA_LLM_LIBRARY="${OLLAMA_LLM_LIBRARY:-cpu_avx2}"
nohup ollama serve >>"$LOG" 2>&1 &
echo "Started ollama serve (PID $!); log: $LOG"
