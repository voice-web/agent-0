#!/usr/bin/env bash
# Stop Open WebUI compose stack only (does not quit Ollama or OrbStack).
# Run from anywhere:  projects/local-ai/scripts/stop-poc.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> local-ai — docker compose down (project dir: ${ROOT})"
docker compose down

echo "    Stopped open-webui container. Named volume 'open-webui' is kept (WebUI data)."
echo "    Ollama and OrbStack are still running if they were before."
