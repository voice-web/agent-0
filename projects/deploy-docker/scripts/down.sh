#!/usr/bin/env bash
set -euo pipefail

# Tear down deployment stacks (application project first, then edge / network).
# Usage:
#   ./scripts/down.sh [--volumes] <deployment-dirname>
#   e.g. local-path-127, vm-host-oci (directory name under deployments/)

VOL_OPTS=()
if [[ "${1:-}" == "--volumes" ]]; then
  VOL_OPTS=(--volumes)
  shift
fi

DEPLOYMENT_DIRNAME="${1:-}"
if [[ -z "$DEPLOYMENT_DIRNAME" ]]; then
  echo "Usage: $0 [--volumes] <deployment-dirname>" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export GLOBE_LANDING_ASSETS="${GLOBE_LANDING_ASSETS:-/Users/ray.jimenez/worldcliques/git/vap/projects/globe-landing/site/assets}"

DEPLOY_DIR="$ROOT_DIR/deployments/$DEPLOYMENT_DIRNAME"
if [[ ! -f "$DEPLOY_DIR/deployment.json" ]]; then
  echo "Unknown deployment: $DEPLOYMENT_DIRNAME" >&2
  exit 2
fi

echo "==> compile (for compose paths)"
python3 "$ROOT_DIR/scripts/compile.py" "$DEPLOYMENT_DIRNAME" >/dev/null

GENDIR="$(python3 "$ROOT_DIR/scripts/bundle_paths.py" gendir "$DEPLOYMENT_DIRNAME")"
RESOLVED="$GENDIR/resolved.json"

EDGE_PROJECT="$(
  python3 -c "import json; print(json.load(open('$RESOLVED'))['compose_projects']['edge'])"
)"
APP_PROJECT="$(
  python3 -c "import json; print(json.load(open('$RESOLVED'))['compose_projects']['application'])"
)"
EDGE_COMPOSE="$(
  python3 -c "import json; print(json.load(open('$RESOLVED'))['paths']['edge_compose'])"
)"

KEYCLOAK_TMP_ENV_FILE=""
KC_USE=""
if [[ -v KEYCLOAK_ENV_FILE ]] && [[ -f "$KEYCLOAK_ENV_FILE" ]]; then
  KC_USE="$KEYCLOAK_ENV_FILE"
elif KC_TRY="$(
  python3 "$ROOT_DIR/scripts/resolve_keycloak_env.py" "$DEPLOY_DIR"
)" && [[ -f "$KC_TRY" ]]; then
  KC_USE="$KC_TRY"
fi
if [[ -n "$KC_USE" ]]; then
  export KEYCLOAK_ENV_FILE="$KC_USE"
else
  KEYCLOAK_TMP_ENV_FILE="$(mktemp)"
  printf 'KEYCLOAK_ADMIN=admin\nKEYCLOAK_ADMIN_PASSWORD=change-me\n' >"$KEYCLOAK_TMP_ENV_FILE"
  export KEYCLOAK_ENV_FILE="$KEYCLOAK_TMP_ENV_FILE"
  cleanup_tmp() {
    rm -f "$KEYCLOAK_TMP_ENV_FILE" >/dev/null 2>&1 || true
  }
  trap cleanup_tmp EXIT
fi

APP_COMPOSE_REL="$(
  python3 -c "import json; d=json.load(open('$RESOLVED'))['paths'].get('app_compose'); print(d or '')"
)"

if [[ -n "$APP_COMPOSE_REL" && -f "$APP_COMPOSE_REL" ]]; then
  echo "==> docker compose down (application): $APP_PROJECT"
  docker compose -p "$APP_PROJECT" -f "$APP_COMPOSE_REL" down --remove-orphans "${VOL_OPTS[@]}" || true
fi

echo "==> docker compose down (edge): $EDGE_PROJECT"
docker compose -p "$EDGE_PROJECT" -f "$EDGE_COMPOSE" down --remove-orphans "${VOL_OPTS[@]}"

echo "OK"
