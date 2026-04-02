#!/usr/bin/env bash
set -euo pipefail

# Bring down the local stack for a given environment.
# Usage:
#   ./scripts/down.sh 127.0.0.1
#   ./scripts/down.sh --volumes 127.0.0.1

VOL_OPTS=()
if [[ "${1:-}" == "--volumes" ]]; then
  VOL_OPTS=(--volumes)
  shift
fi

ENVIRONMENT="${1:-}"
if [[ -z "$ENVIRONMENT" ]]; then
  echo "Usage: $0 [--volumes] <127.0.0.1>" >&2
  exit 2
fi

if [[ "$ENVIRONMENT" != "127.0.0.1" ]]; then
  echo "This reference script currently supports environment: 127.0.0.1" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Ensure docker-compose variable substitution has safe defaults.
# This avoids invalid volume specs like ":/srv/www/assets:ro" when env vars are unset.
export GLOBE_LANDING_ASSETS="${GLOBE_LANDING_ASSETS:-/Users/ray.jimenez/worldcliques/git/vap/projects/globe-landing/site/assets}"

# Same sanitization logic as up.sh
SAFE_ENVIRONMENT="$(echo "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')"
SAFE_ENVIRONMENT="${SAFE_ENVIRONMENT//./-}"
SAFE_ENVIRONMENT="$(echo "$SAFE_ENVIRONMENT" | sed -E 's/[^a-z0-9_-]+/-/g')"

# Keycloak admin credentials are provided via env_file.
# If the real secret file doesn't exist, create a temporary one so
# `docker compose down` can still parse the compose file.
DEFAULT_KEYCLOAK_ENV_FILE="${KEYCLOAK_ENV_FILE:-${HOME}/.secrets/worldcliques/${ENVIRONMENT}/keycloak.env}"
KEYCLOAK_TMP_ENV_FILE=""
if [[ ! -f "$DEFAULT_KEYCLOAK_ENV_FILE" ]]; then
  KEYCLOAK_TMP_ENV_FILE="$(mktemp)"
  cat >"$KEYCLOAK_TMP_ENV_FILE" <<EOF
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=change-me
EOF
  export KEYCLOAK_ENV_FILE="$KEYCLOAK_TMP_ENV_FILE"
  cleanup_tmp() {
    rm -f "$KEYCLOAK_TMP_ENV_FILE" >/dev/null 2>&1 || true
  }
  trap cleanup_tmp EXIT
else
  export KEYCLOAK_ENV_FILE="$DEFAULT_KEYCLOAK_ENV_FILE"
fi

PROJECT_NAME="wc-${SAFE_ENVIRONMENT}"

INFRA_COMPOSE_FILE="compose/infra-${ENVIRONMENT}.yml"
APP_COMPOSE_FILE="compose/application-${ENVIRONMENT}.yml"

if [[ ! -f "$INFRA_COMPOSE_FILE" ]]; then
  echo "Missing compose file: $INFRA_COMPOSE_FILE" >&2
  exit 2
fi

# application compose may be missing; infra down should still work.

echo "==> docker compose down (infra)"
docker compose -p "$PROJECT_NAME" -f "$INFRA_COMPOSE_FILE" down --remove-orphans "${VOL_OPTS[@]}"

if [[ -f "$APP_COMPOSE_FILE" ]]; then
  echo "==> docker compose down (application)"
  docker compose -p "$PROJECT_NAME" -f "$APP_COMPOSE_FILE" down --remove-orphans "${VOL_OPTS[@]}"
fi

echo "OK"

