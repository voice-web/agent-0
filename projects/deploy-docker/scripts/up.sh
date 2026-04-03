#!/usr/bin/env bash
set -euo pipefail

# Bring up stacks from compiled deployment bundles (see DEPLOYMENT_MODEL.md).
#
# Usage:
#   ./scripts/up.sh <deployment-dirname> [infra|application] ...
#   ./scripts/up.sh <deployment-dirname>                    # infra + application
#   ./scripts/up.sh infra <deployment-dirname>
#   ./scripts/up.sh application <deployment-dirname>
#
# <deployment-dirname> is the directory under deployments/, e.g. local-path-127, vm-host-oci.

REQUESTED_MANIFESTS=()
DEPLOYMENT_DIRNAME=""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export GLOBE_LANDING_ASSETS="${GLOBE_LANDING_ASSETS:-/Users/ray.jimenez/worldcliques/git/vap/projects/globe-landing/site/assets}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <deployment-dirname> [infra|application ...]" >&2
  echo "       $0 infra|application <deployment-dirname>" >&2
  exit 2
fi

case "$1" in
  infra|application)
    REQUESTED_MANIFESTS=("$1")
    DEPLOYMENT_DIRNAME="${2:-}"
    if [[ -z "$DEPLOYMENT_DIRNAME" || -n "${3:-}" ]]; then
      echo "Usage: $0 <infra|application> <deployment-dirname>" >&2
      exit 2
    fi
    ;;
  *)
    DEPLOYMENT_DIRNAME="$1"
    shift
    if [[ $# -eq 0 ]]; then
      REQUESTED_MANIFESTS=(infra application)
    else
      REQUESTED_MANIFESTS=("$@")
    fi
    ;;
esac

DEPLOY_DIR="$ROOT_DIR/deployments/$DEPLOYMENT_DIRNAME"
if [[ ! -f "$DEPLOY_DIR/deployment.json" ]]; then
  echo "Unknown deployment '$DEPLOYMENT_DIRNAME' (no $DEPLOY_DIR/deployment.json)" >&2
  exit 2
fi

for m in "${REQUESTED_MANIFESTS[@]}"; do
  case "$m" in
    infra|application) ;;
    *)
      echo "Unknown manifest set: $m (expected infra or application)" >&2
      exit 2
      ;;
  esac
done

ORDERED_MANIFESTS=()
for want in infra application; do
  for m in "${REQUESTED_MANIFESTS[@]}"; do
    if [[ "$m" == "$want" ]]; then
      ORDERED_MANIFESTS+=("$m")
      break
    fi
  done
done

if [[ -v KEYCLOAK_ENV_FILE ]]; then
  if [[ ! -f "$KEYCLOAK_ENV_FILE" ]]; then
    echo "KEYCLOAK_ENV_FILE is set but file not found: $KEYCLOAK_ENV_FILE" >&2
    exit 1
  fi
else
  KEYCLOAK_ENV_FILE="$(
    python3 "$ROOT_DIR/scripts/resolve_keycloak_env.py" "$DEPLOY_DIR"
  )" || exit 1
  export KEYCLOAK_ENV_FILE
fi

includes_manifest() {
  local want="$1"
  local m
  for m in "${ORDERED_MANIFESTS[@]}"; do
    if [[ "$m" == "$want" ]]; then
      return 0
    fi
  done
  return 1
}

echo "==> compile: deployment=$DEPLOYMENT_DIRNAME"
python3 "$ROOT_DIR/scripts/compile.py" "$DEPLOYMENT_DIRNAME"

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
BUNDLE_KIND="$(
  python3 -c "import json; print(json.load(open('$RESOLVED')).get('bundle_kind','standard'))"
)"
APP_COMPOSE_REL="$(
  python3 -c "import json; d=json.load(open('$RESOLVED'))['paths'].get('app_compose'); print(d or '')"
)"

EXPECTED_IMAGES="$(
  python3 -c "import json; print(' '.join(json.load(open('$RESOLVED'))['expected_images']))"
)"

check_images_missing() {
  local -a images=("$@")
  local -a missing=()
  local -a present=()
  for img in "${images[@]}"; do
    if docker image inspect "$img" >/dev/null 2>&1; then
      present+=("$img")
    else
      missing+=("$img")
    fi
  done
  echo "==> Image check"
  if ((${#present[@]} > 0)); then
    echo "Present:"
    for i in "${present[@]}"; do echo "  - $i"; done
  fi
  if ((${#missing[@]} > 0)); then
    echo "Missing:"
    for i in "${missing[@]}"; do echo "  - $i"; done
    return 1
  fi
  return 0
}

read -r -a IMG_ARR <<< "$EXPECTED_IMAGES"
if ! check_images_missing "${IMG_ARR[@]}"; then
  echo >&2
  echo "Build missing images from ../docker-images, then rerun." >&2
  exit 2
fi

if includes_manifest infra; then
  if [[ -z "$EDGE_COMPOSE" || ! -f "$EDGE_COMPOSE" ]]; then
    echo "==> Skipping infra: no edge stack (bundle_kind=$BUNDLE_KIND)"
  else
    KC_REQUIRED="$(
      python3 -c "import json; r=json.load(open('$RESOLVED')); es=r.get('edge_service_names'); print('yes' if (es is None or 'keycloak' in es) else 'no')"
    )"
    if [[ "$KC_REQUIRED" == "yes" ]] && [[ ! -f "$KEYCLOAK_ENV_FILE" ]]; then
      echo "==> Missing Keycloak env_file: $KEYCLOAK_ENV_FILE" >&2
      echo "Create it with KEYCLOAK_ADMIN and KEYCLOAK_ADMIN_PASSWORD (see DEPLOY_LOCAL.md)" >&2
      exit 1
    fi
    echo "==> docker compose up (edge): project=$EDGE_PROJECT"
    docker compose -p "$EDGE_PROJECT" -f "$EDGE_COMPOSE" up -d
  fi
fi

if includes_manifest application; then
  if [[ -z "$APP_COMPOSE_REL" ]]; then
    echo "==> Skipping application: no services enabled in deployment config"
  else
    NET_NAME="$(
      python3 -c "import json; print(json.load(open('$RESOLVED'))['network_name'])"
    )"
    if [[ "$BUNDLE_KIND" != "tools" ]]; then
      if ! docker network inspect "$NET_NAME" >/dev/null 2>&1; then
        echo "Network '$NET_NAME' not found. Run infra first." >&2
        exit 1
      fi
    fi
    echo "==> docker compose up (application): project=$APP_PROJECT"
    docker compose -p "$APP_PROJECT" -f "$APP_COMPOSE_REL" up -d
  fi
fi

echo "OK"
echo
echo "==> Generated: $GENDIR — see resolved.json"
echo "    Edge project: ${EDGE_PROJECT:-—}"
echo "    App project:  $APP_PROJECT"

python3 "$ROOT_DIR/scripts/print_routes.py" "$DEPLOYMENT_DIRNAME"
