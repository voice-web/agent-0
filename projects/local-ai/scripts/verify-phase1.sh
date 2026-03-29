#!/usr/bin/env bash
# Exit 0 if Phase 1 baseline is satisfied (Ollama API + ~/vap-sandbox-0 + starter files).
# Usage: from projects/local-ai — ./scripts/verify-phase1.sh
# Override sandbox: VAP_SANDBOX=/path ./scripts/verify-phase1.sh

set -euo pipefail

SANDBOX="${VAP_SANDBOX:-$HOME/vap-sandbox-0}"
TAGS="$(mktemp)"
trap 'rm -f "$TAGS"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

command -v ollama >/dev/null || fail "ollama not in PATH"
ollama --version >/dev/null 2>&1 || true

code="$(curl -s -o "$TAGS" -w "%{http_code}" http://127.0.0.1:11434/api/tags)"
[[ "$code" == "200" ]] || fail "GET /api/tags HTTP $code (expected 200)"

python3 -c "import json,sys; p=json.load(open(sys.argv[1])); assert p.get('models'), 'no models'" "$TAGS" \
  || fail "no models in /api/tags JSON"

[[ -d "$SANDBOX" ]] || fail "missing directory $SANDBOX (mkdir -p \"$SANDBOX\")"
[[ -f "$SANDBOX/notes.md" ]] || fail "missing $SANDBOX/notes.md (copy from sandbox-starters/)"
[[ -f "$SANDBOX/hello.py" ]] || fail "missing $SANDBOX/hello.py (copy from sandbox-starters/)"

echo "OK: Phase 1 baseline — Ollama /api/tags has models; $SANDBOX has notes.md and hello.py"
