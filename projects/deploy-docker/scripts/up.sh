#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT=""
REQUESTED_MANIFESTS=()

if [[ $# -lt 2 ]]; then
  echo "Usage:"
  echo "  $0 <infra|application> <127.0.0.1>              # legacy"
  echo "  $0 <127.0.0.1> <infra|application> [more...]   # new: env first"
  exit 2
fi

SUPPORTED_ENV="127.0.0.1"

case "$1" in
  infra|application)
    # Legacy: <manifest> <env>
    REQUESTED_MANIFESTS=("$1")
    ENVIRONMENT="${2:-}"
    ;;
  "$SUPPORTED_ENV")
    # New: <env> <manifest...>
    ENVIRONMENT="$1"
    shift
    REQUESTED_MANIFESTS=("$@")
    ;;
  *)
    echo "Unrecognized arguments." >&2
    echo "Expected either:" >&2
    echo "  $0 <infra|application> 127.0.0.1" >&2
    echo "or" >&2
    echo "  $0 127.0.0.1 <infra|application> [more...]" >&2
    exit 2
    ;;
esac

if [[ "$ENVIRONMENT" != "$SUPPORTED_ENV" ]]; then
  echo "This reference script currently supports environment: $SUPPORTED_ENV" >&2
  exit 2
fi

for m in "${REQUESTED_MANIFESTS[@]}"; do
  case "$m" in
    infra|application)
      ;;
    *)
      echo "Unknown manifest set: $m (expected infra or application)" >&2
      exit 2
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export GLOBE_LANDING_ASSETS="${GLOBE_LANDING_ASSETS:-/Users/ray.jimenez/worldcliques/git/vap/projects/globe-landing/site/assets}"

# Keycloak admin credentials are read from env_file.
# Put the secret at:
#   ~/.secrets/worldcliques/<environment>/keycloak.env
# and don't commit it.
export KEYCLOAK_ENV_FILE="${KEYCLOAK_ENV_FILE:-${HOME}/.secrets/worldcliques/${ENVIRONMENT}/keycloak.env}"

# Local image preflight check
# Fail early with a clear message so the user knows which images to build.
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
    for i in "${present[@]}"; do
      echo "  - $i"
    done
  fi

  if ((${#missing[@]} > 0)); then
    echo "Missing:"
    for i in "${missing[@]}"; do
      echo "  - $i"
    done
    return 1
  fi

  return 0
}

# docker compose project names must match:
#   lowercase alphanumeric, hyphens, underscores, and start with a letter/number
# so we sanitize IP-like environments (e.g. 127.0.0.1 -> 127-0-0-1).
SAFE_ENVIRONMENT="$(echo "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')"
SAFE_ENVIRONMENT="${SAFE_ENVIRONMENT//./-}"
SAFE_ENVIRONMENT="$(echo "$SAFE_ENVIRONMENT" | sed -E 's/[^a-z0-9_-]+/-/g')"

PROJECT_NAME="wc-${SAFE_ENVIRONMENT}"
NET_NAME="wc-${SAFE_ENVIRONMENT}-net"

includes_manifest() {
  local wanted="$1"
  local m
  for m in "${REQUESTED_MANIFESTS[@]}"; do
    if [[ "$m" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

ORDERED_MANIFESTS=()
if includes_manifest infra; then
  ORDERED_MANIFESTS+=("infra")
fi
if includes_manifest application; then
  ORDERED_MANIFESTS+=("application")
fi

STARTED_INFRA="no"
STARTED_APPLICATION="no"

if includes_manifest infra; then
  if [[ ! -f "$KEYCLOAK_ENV_FILE" ]]; then
    echo "==> Missing Keycloak admin secret env_file:" >&2
    echo "  $KEYCLOAK_ENV_FILE" >&2
    echo >&2
    echo "Create it with contents like:" >&2
    echo "  KEYCLOAK_ADMIN=admin" >&2
    echo "  KEYCLOAK_ADMIN_PASSWORD=change-me" >&2
    echo >&2
    echo "Example:" >&2
    echo "  mkdir -p \"$(dirname "$KEYCLOAK_ENV_FILE")\"" >&2
    echo "  printf 'KEYCLOAK_ADMIN=admin\\nKEYCLOAK_ADMIN_PASSWORD=change-me\\n' > \"$KEYCLOAK_ENV_FILE\"" >&2
    echo >&2
    echo "Then rerun:" >&2
    echo "  ./scripts/up.sh $ENVIRONMENT infra" >&2
    echo "  ./scripts/up.sh $ENVIRONMENT infra application" >&2
    exit 1
  fi
fi

EXPECTED_IMAGES=()
if includes_manifest infra; then
  EXPECTED_IMAGES+=("local/caddy:2.8.4" "local/keycloak:26.0.5")
fi
if includes_manifest application; then
  EXPECTED_IMAGES+=("local/default-html:0.0.1" "local/default-api-json:0.0.1")
fi

if ! check_images_missing "${EXPECTED_IMAGES[@]}"; then
  echo >&2
  echo "Build missing images, then rerun." >&2
  echo "From this directory:" >&2
  echo "  cd ../docker-images" >&2
  if includes_manifest infra; then
    echo "  ./scripts/build-local.sh external/caddy" >&2
    echo "  ./scripts/build-local.sh external/keycloak" >&2
  fi
  if includes_manifest application; then
    echo "  ./scripts/build-local.sh internal/default-html" >&2
    echo "  ./scripts/build-local.sh internal/default-api-json" >&2
  fi
  exit 2
fi

for MANIFEST_SET in "${ORDERED_MANIFESTS[@]}"; do
  COMPOSE_FILE=""
  case "$MANIFEST_SET" in
    infra)
      COMPOSE_FILE="compose/infra-${ENVIRONMENT}.yml"
      STARTED_INFRA="yes"
      ;;
    application)
      COMPOSE_FILE="compose/application-${ENVIRONMENT}.yml"
      STARTED_APPLICATION="yes"
      ;;
  esac

  if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "Missing compose file: $COMPOSE_FILE" >&2
    exit 2
  fi

  if [[ "$MANIFEST_SET" == "application" ]]; then
    # application up assumes infra already ran (caddy + keycloak + network).
    if ! docker network inspect "$NET_NAME" >/dev/null 2>&1; then
      echo "Network '$NET_NAME' not found. Run infra first." >&2
      exit 1
    fi
  fi

  echo "==> docker compose up: manifest=$MANIFEST_SET env=$ENVIRONMENT project=$PROJECT_NAME"
  docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d
done

echo "OK"

echo
echo "==> Routes and ports (127.0.0.1)"
if [[ "$STARTED_INFRA" == "yes" ]]; then
  echo "- Caddy edge listener: http://127.0.0.1:80"
  echo "- Web HTML:"
  echo "  - GET http://127.0.0.1:80/ -> default-html (index.html)"
  echo "  - GET http://127.0.0.1:80/health -> default-html /health (JSON)"
  echo "  - GET http://127.0.0.1:80/* (except /api/* and /auth/*) -> HTML error page"
  echo "- API JSON:"
  echo "  - GET http://127.0.0.1:80/api/health -> default-api-json /health (JSON)"
  echo "  - GET http://127.0.0.1:80/api/* -> default-api-json JSON 404 stub"
  echo "- Keycloak:"
  echo "  - GET http://127.0.0.1:80/auth/ -> keycloak"
  echo "  - GET http://127.0.0.1:80/auth/* -> keycloak"
else
  echo "- Infra was not started; Caddy is not running, so host routing on :80 is not available."
fi

