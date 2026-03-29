#!/usr/bin/env bash
# Optional: create the first admin via HTTP API (signup) after WebUI is already up.
# Prefer WEBUI_ADMIN_EMAIL / WEBUI_ADMIN_PASSWORD in `.env` + docker compose instead.
#
# Reads WEBUI_ADMIN_EMAIL, WEBUI_ADMIN_PASSWORD, WEBUI_ADMIN_NAME from the environment.
# If `projects/local-ai/.env` exists, loads it (simple KEY=value lines only).
#
# Usage (from projects/local-ai):
#   WEBUI_ADMIN_EMAIL=a@b.c WEBUI_ADMIN_PASSWORD=secret ./scripts/create-webui-admin-api.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBUI_URL="${WEBUI_URL:-http://127.0.0.1:${LOCAL_AI_WEBUI_PORT:-3000}}"

load_dotenv() {
  [[ -f "$ROOT/.env" ]] || return 0
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
}

load_dotenv

: "${WEBUI_ADMIN_EMAIL:?Set WEBUI_ADMIN_EMAIL (or add to .env)}"
: "${WEBUI_ADMIN_PASSWORD:?Set WEBUI_ADMIN_PASSWORD (or add to .env)}"
NAME="${WEBUI_ADMIN_NAME:-Admin}"

echo "==> Waiting for Open WebUI at ${WEBUI_URL} …"
for _ in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 5 "${WEBUI_URL}/" 2>/dev/null || true)"
  [[ "$code" =~ ^(200|301|302|303)$ ]] && break
  sleep 2
done

BODY="$(WEBUI_ADMIN_EMAIL="$WEBUI_ADMIN_EMAIL" WEBUI_ADMIN_PASSWORD="$WEBUI_ADMIN_PASSWORD" NAME="$NAME" python3 - <<'PY'
import json, os
print(json.dumps({
    "email": os.environ["WEBUI_ADMIN_EMAIL"],
    "name": os.environ["NAME"],
    "password": os.environ["WEBUI_ADMIN_PASSWORD"],
}))
PY
)"

echo "==> POST /api/v1/auths/signup (first user only) …"
resp="$(curl -sS -w "\n%{http_code}" -X POST "${WEBUI_URL}/api/v1/auths/signup" \
  -H "Content-Type: application/json" \
  -d "$BODY")"
http="${resp##*$'\n'}"
body="${resp%$'\n'*}"

if [[ "$http" =~ ^2 ]]; then
  echo "OK: signup returned HTTP $http"
  exit 0
fi

if echo "$body" | grep -qi 'already\|exist\|sign up.*disabled'; then
  echo "OK: admin or signup policy already set (HTTP $http) — no action needed."
  exit 0
fi

echo "error: signup failed HTTP $http" >&2
echo "$body" >&2
exit 1
