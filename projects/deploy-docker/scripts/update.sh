#!/usr/bin/env bash
set -euo pipefail

# Recreate one service container (picks up rebuilt images with same tag).
# Usage:
#   ./scripts/update.sh <infra|application> <deployment> <service>
#
# Example:
#   ./scripts/update.sh application local-path-127 globe-landing
#   ./scripts/update.sh infra vm-host-oci caddy

MANIFEST_SET="${1:-}"
DEPLOYMENT_ID="${2:-}"
SERVICE_NAME="${3:-}"

if [[ -z "$MANIFEST_SET" || -z "$DEPLOYMENT_ID" || -z "$SERVICE_NAME" ]]; then
  echo "Usage: $0 <infra|application> <deployment> <service>" >&2
  exit 2
fi

case "$MANIFEST_SET" in
  infra|application) ;;
  *)
    echo "Invalid manifest: $MANIFEST_SET" >&2
    exit 2
    ;;
esac

case "$DEPLOYMENT_ID" in
  127.0.0.1) DEPLOYMENT_ID="local-path-127" ;;
  oci-vm) DEPLOYMENT_ID="vm-host-oci" ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export GLOBE_LANDING_ASSETS="${GLOBE_LANDING_ASSETS:-/Users/ray.jimenez/worldcliques/git/vap/projects/globe-landing/site/assets}"
DEPLOY_DIR="$ROOT_DIR/deployments/$DEPLOYMENT_ID"
CONFIG_ENV_NAME="$(
  python3 -c "import json, pathlib; print(json.loads(pathlib.Path('$DEPLOY_DIR/config.json').read_text())['env_name'])"
)"
export KEYCLOAK_ENV_FILE="${KEYCLOAK_ENV_FILE:-${HOME}/.secrets/worldcliques/${CONFIG_ENV_NAME}/keycloak.env}"

python3 "$ROOT_DIR/scripts/compile.py" "$DEPLOYMENT_ID" >/dev/null
GENDIR="$ROOT_DIR/.generated/$DEPLOYMENT_ID"
RESOLVED="$GENDIR/resolved.json"

if [[ "$MANIFEST_SET" == "infra" ]]; then
  PROJECT="$(
    python3 -c "import json; print(json.load(open('$RESOLVED'))['compose_projects']['edge'])"
  )"
  COMPOSE="$(
    python3 -c "import json; print(json.load(open('$RESOLVED'))['paths']['edge_compose'])"
  )"
else
  PROJECT="$(
    python3 -c "import json; print(json.load(open('$RESOLVED'))['compose_projects']['application'])"
  )"
  COMPOSE="$(
    python3 -c "import json; d=json.load(open('$RESOLVED'))['paths'].get('app_compose'); print(d or '')"
  )"
  if [[ -z "$COMPOSE" || ! -f "$COMPOSE" ]]; then
    echo "No application compose (services disabled?)" >&2
    exit 2
  fi
fi

SERVICE_FOUND="false"
while IFS= read -r svc; do
  if [[ "$svc" == "$SERVICE_NAME" ]]; then
    SERVICE_FOUND="true"
    break
  fi
done < <(docker compose -p "$PROJECT" -f "$COMPOSE" config --services)

if [[ "$SERVICE_FOUND" != "true" ]]; then
  echo "Service '$SERVICE_NAME' not found in $MANIFEST_SET compose" >&2
  docker compose -p "$PROJECT" -f "$COMPOSE" config --services >&2
  exit 2
fi

echo "==> compose up --force-recreate: project=$PROJECT service=$SERVICE_NAME"
docker compose -p "$PROJECT" -f "$COMPOSE" up -d --no-deps --force-recreate "$SERVICE_NAME"
echo "OK"
