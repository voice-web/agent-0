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

CONFIG_ENV_NAME="$(
  python3 -c "import json, pathlib; print(json.loads(pathlib.Path('$DEPLOY_DIR/config.json').read_text())['env_name'])"
)"
DEFAULT_KEYCLOAK_ENV_FILE="${KEYCLOAK_ENV_FILE:-${HOME}/.secrets/worldcliques/${CONFIG_ENV_NAME}/keycloak.env}"
KEYCLOAK_TMP_ENV_FILE=""
if [[ ! -f "$DEFAULT_KEYCLOAK_ENV_FILE" ]]; then
  KEYCLOAK_TMP_ENV_FILE="$(mktemp)"
  printf 'KEYCLOAK_ADMIN=admin\nKEYCLOAK_ADMIN_PASSWORD=change-me\n' >"$KEYCLOAK_TMP_ENV_FILE"
  export KEYCLOAK_ENV_FILE="$KEYCLOAK_TMP_ENV_FILE"
  cleanup_tmp() {
    rm -f "$KEYCLOAK_TMP_ENV_FILE" >/dev/null 2>&1 || true
  }
  trap cleanup_tmp EXIT
else
  export KEYCLOAK_ENV_FILE="$DEFAULT_KEYCLOAK_ENV_FILE"
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
