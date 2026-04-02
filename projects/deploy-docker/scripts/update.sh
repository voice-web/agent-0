#!/usr/bin/env bash
set -euo pipefail

# Update one service container in place for a given manifest/environment.
# Usage:
#   ./scripts/update.sh <infra|application> <127.0.0.1> <service>
#
# Example:
#   ./scripts/update.sh application 127.0.0.1 globe-landing

MANIFEST_SET="${1:-}"
ENVIRONMENT="${2:-}"
SERVICE_NAME="${3:-}"

if [[ -z "$MANIFEST_SET" || -z "$ENVIRONMENT" || -z "$SERVICE_NAME" ]]; then
  echo "Usage: $0 <infra|application> <127.0.0.1|oci-vm> <service>" >&2
  exit 2
fi

case "$MANIFEST_SET" in
  infra|application)
    ;;
  *)
    echo "Invalid manifest: $MANIFEST_SET (expected infra or application)" >&2
    exit 2
    ;;
esac

case "$ENVIRONMENT" in
  127.0.0.1 | oci-vm) ;;
  *)
    echo "This reference script currently supports environments: 127.0.0.1, oci-vm" >&2
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Environment defaults used by compose interpolation.
export GLOBE_LANDING_ASSETS="${GLOBE_LANDING_ASSETS:-/Users/ray.jimenez/worldcliques/git/vap/projects/globe-landing/site/assets}"
export KEYCLOAK_ENV_FILE="${KEYCLOAK_ENV_FILE:-${HOME}/.secrets/worldcliques/${ENVIRONMENT}/keycloak.env}"

# If infra compose needs Caddyfile path and generated one exists, prefer it.
if [[ -z "${CADDYFILE_PATH:-}" ]]; then
  GENERATED_CADDYFILE="$ROOT_DIR/.generated/Caddyfile-${ENVIRONMENT}"
  if [[ -f "$GENERATED_CADDYFILE" ]]; then
    export CADDYFILE_PATH="$GENERATED_CADDYFILE"
  else
    export CADDYFILE_PATH="../examples/routing/Caddyfile-${ENVIRONMENT}"
  fi
fi

# Same sanitization logic as up/down.
SAFE_ENVIRONMENT="$(echo "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')"
SAFE_ENVIRONMENT="${SAFE_ENVIRONMENT//./-}"
SAFE_ENVIRONMENT="$(echo "$SAFE_ENVIRONMENT" | sed -E 's/[^a-z0-9_-]+/-/g')"

PROJECT_NAME="wc-${SAFE_ENVIRONMENT}"
COMPOSE_FILE="compose/${MANIFEST_SET}-${ENVIRONMENT}.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Missing compose file: $COMPOSE_FILE" >&2
  exit 2
fi

# Validate service exists in selected manifest compose file.
SERVICE_FOUND="false"
while IFS= read -r svc; do
  if [[ "$svc" == "$SERVICE_NAME" ]]; then
    SERVICE_FOUND="true"
    break
  fi
done < <(docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" config --services)

if [[ "$SERVICE_FOUND" != "true" ]]; then
  echo "Service '$SERVICE_NAME' not found in $COMPOSE_FILE" >&2
  echo "Available services:" >&2
  docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" config --services >&2
  exit 2
fi

echo "==> Updating service"
echo "manifest: $MANIFEST_SET"
echo "environment: $ENVIRONMENT"
echo "service: $SERVICE_NAME"
echo "project: $PROJECT_NAME"

# --force-recreate ensures container is recreated even when config appears unchanged.
# This picks up rebuilt local images even if the image tag is the same.
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d --no-deps --force-recreate "$SERVICE_NAME"

echo "OK"

