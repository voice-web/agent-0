#!/usr/bin/env bash
set -euo pipefail

# Tear down deployment stacks (application project first, then edge / network).
#
# The tools bundle (recon-lab) is a separate deployment: local-tools-127. Bringing
# down local-ports-127 or local-path-127 does NOT stop it unless you pass --with-tools
# or run: ./scripts/down.sh local-tools-127
#
# Usage:
#   ./scripts/down.sh [--volumes] [--with-tools] <deployment-dirname>
#   e.g. local-path-127, vm-host-oci (directory name under deployments/)

VOL_OPTS=()
WITH_TOOLS=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --volumes)
      VOL_OPTS=(--volumes)
      ;;
    --with-tools)
      WITH_TOOLS=1
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--volumes] [--with-tools] <deployment-dirname>" >&2
      exit 2
      ;;
  esac
  shift
done

DEPLOYMENT_DIRNAME="${1:-}"
if [[ -z "$DEPLOYMENT_DIRNAME" ]]; then
  echo "Usage: $0 [--volumes] [--with-tools] <deployment-dirname>" >&2
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
  python3 -c "import json; p=json.load(open('$RESOLVED'))['compose_projects'].get('edge'); print(p if p else '')"
)"
APP_PROJECT="$(
  python3 -c "import json; print(json.load(open('$RESOLVED'))['compose_projects']['application'])"
)"
EDGE_COMPOSE="$(
  python3 -c "import json; p=json.load(open('$RESOLVED'))['paths'].get('edge_compose'); print(p if p else '')"
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

if [[ -n "$EDGE_COMPOSE" && -f "$EDGE_COMPOSE" ]]; then
  echo "==> docker compose down (edge): $EDGE_PROJECT"
  docker compose -p "$EDGE_PROJECT" -f "$EDGE_COMPOSE" down --remove-orphans "${VOL_OPTS[@]}"
else
  echo "==> Skipping edge down (no edge stack)"
fi

down_tools_bundle() {
  local tools_dirname="$1"
  local tools_deploy="$ROOT_DIR/deployments/$tools_dirname"
  if [[ ! -f "$tools_deploy/deployment.json" ]]; then
    echo "==> Skipping tools down (no deployment $tools_dirname)" >&2
    return 0
  fi
  echo "==> compile (tools companion): $tools_dirname"
  python3 "$ROOT_DIR/scripts/compile.py" "$tools_dirname" >/dev/null
  local tg
  tg="$(python3 "$ROOT_DIR/scripts/bundle_paths.py" gendir "$tools_dirname")"
  local tresolved="$tg/resolved.json"
  local tproj
  tproj="$(python3 -c "import json; print(json.load(open('$tresolved'))['compose_projects']['application'])")"
  local tcompose
  tcompose="$(python3 -c "import json; d=json.load(open('$tresolved'))['paths'].get('app_compose'); print(d or '')")"
  if [[ -z "$tcompose" || ! -f "$tcompose" ]]; then
    echo "==> Skipping tools down (no app compose for $tools_dirname)"
    return 0
  fi
  echo "==> docker compose down (tools): $tproj"
  docker compose -p "$tproj" -f "$tcompose" down --remove-orphans "${VOL_OPTS[@]}" || true
}

if [[ "$WITH_TOOLS" -eq 1 ]]; then
  case "$DEPLOYMENT_DIRNAME" in
    local-ports-127 | local-path-127)
      down_tools_bundle "local-tools-127"
      ;;
    *)
      echo "==> --with-tools only chains local-tools-127 after local-ports-127 or local-path-127 (skipped)" >&2
      ;;
  esac
elif [[ "$DEPLOYMENT_DIRNAME" == "local-ports-127" || "$DEPLOYMENT_DIRNAME" == "local-path-127" ]]; then
  echo "==> Note: recon-lab (local-tools-127) is a separate compose project; it is still running."
  echo "    Stop it: $0 local-tools-127   (add --volumes before the name if you use --volumes here)"
  echo "    Or one shot: $0 --with-tools $DEPLOYMENT_DIRNAME"
fi

echo "OK"
