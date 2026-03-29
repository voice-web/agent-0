#!/usr/bin/env bash
# Phase 3 — pin asdf versions for python (prefer 3.12.x), poetry, ollama in projects/local-ai/.tool-versions
# and run `asdf install`. Then you run: poetry install (use standard CPython, not 3.14t).
#
# Prerequisites: asdf installed; plugins: python, poetry, ollama
#   asdf plugin add python https://github.com/asdf-community/asdf-python.git
#   asdf plugin add poetry https://github.com/asdf-community/asdf-poetry.git
#   asdf plugin add ollama  # your ollama plugin source, if not default
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Load asdf when run from a non-interactive shell (Cursor tasks, CI).
_load_asdf() {
  if command -v asdf >/dev/null 2>&1; then
    return 0
  fi
  local s
  for s in "${ASDF_DIR:-$HOME/.asdf}/asdf.sh" \
           "/opt/homebrew/opt/asdf/libexec/asdf.sh" \
           "/usr/local/opt/asdf/libexec/asdf.sh"; do
    if [[ -f "$s" ]]; then
      # shellcheck disable=SC1090
      source "$s"
      break
    fi
  done
}
_load_asdf

if ! command -v asdf >/dev/null 2>&1; then
  echo "error: asdf not found. Install asdf and open a login shell, or source asdf.sh." >&2
  exit 1
fi

need_plugin() {
  local p="$1"
  if ! asdf plugin list 2>/dev/null | grep -qx "$p"; then
    echo "error: asdf plugin '$p' is not installed. Add it, then re-run." >&2
    exit 1
  fi
}

need_plugin python
need_plugin poetry
need_plugin ollama

# Prefer `asdf latest <plugin>`; fall back to highest semver from `asdf list all`.
resolve_latest() {
  local plugin="$1"
  local v=""
  v="$(asdf latest "$plugin" 2>/dev/null || true)"
  v="${v//$'\r'/}"
  v="${v//$'\n'/}"
  if [[ -n "$v" && "$v" != *" "* ]]; then
    echo "$v"
    return 0
  fi
  v="$(asdf list all "$plugin" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -E '^[0-9]+\.[0-9]+' | sort -V | tail -n1)"
  if [[ -n "$v" ]]; then
    echo "$v"
    return 0
  fi
  echo "error: could not resolve latest version for asdf plugin '$plugin'." >&2
  exit 1
}

# Avoid 3.14+ and free-threaded (*t): those builds often break `poetry install` for open-interpreter
# (psutil C API, tiktoken wheels / Rust). Prefer latest **3.12.x**; else latest **3.13.x**; else 3.12.3.
resolve_python_for_local_ai() {
  local v
  v="$(asdf list all python 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
    grep -E '^3\.12\.[0-9]+$' | sort -V | tail -n1)"
  if [[ -n "$v" ]]; then
    echo "$v"
    return 0
  fi
  v="$(asdf list all python 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
    grep -E '^3\.13\.[0-9]+$' | sort -V | tail -n1)"
  if [[ -n "$v" ]]; then
    echo "$v"
    return 0
  fi
  echo "3.12.3"
}

PY="$(resolve_python_for_local_ai)"
POETRY="$(resolve_latest poetry)"
OLLAMA="$(resolve_latest ollama)"

echo "==> local-ai Phase 3 — writing ${ROOT}/.tool-versions"
echo "    python  ${PY}  (3.12.x preferred; 3.13.x ok; not 3.14 / *t — see script comments)"
echo "    poetry  ${POETRY}"
echo "    ollama  ${OLLAMA}"

cat >"${ROOT}/.tool-versions" <<EOF
python ${PY}
poetry ${POETRY}
ollama ${OLLAMA}
EOF

echo "==> asdf install (downloads missing runtimes; may take a while)…"
asdf install

echo ""
echo "OK: Phase 3 tool versions pinned. Next (from ${ROOT}):"
echo "    poetry install"
echo "    cd ~/vap-sandbox-0 && poetry -C ${ROOT} run interpreter --model ollama/qwen2.5:0.5b"
