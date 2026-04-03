#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT=""
REQUESTED_MANIFESTS=()

if [[ $# -lt 2 ]]; then
  echo "Usage:"
  echo "  $0 <infra|application> <127.0.0.1|oci-vm>              # legacy"
  echo "  $0 <127.0.0.1|oci-vm> <infra|application> [more...]   # new: env first"
  exit 2
fi

is_supported_env() {
  case "${1:-}" in
    127.0.0.1 | oci-vm) return 0 ;;
    *) return 1 ;;
  esac
}

case "$1" in
  infra|application)
    # Legacy: <manifest> <env>
    REQUESTED_MANIFESTS=("$1")
    ENVIRONMENT="${2:-}"
    ;;
  *)
    if is_supported_env "$1"; then
      # New: <env> <manifest...>
      ENVIRONMENT="$1"
      shift
      REQUESTED_MANIFESTS=("$@")
    else
      echo "Unrecognized arguments." >&2
      echo "Expected either:" >&2
      echo "  $0 <infra|application> <127.0.0.1|oci-vm>" >&2
      echo "or" >&2
      echo "  $0 <127.0.0.1|oci-vm> <infra|application> [more...]" >&2
      exit 2
    fi
    ;;
esac

if ! is_supported_env "$ENVIRONMENT"; then
  echo "This reference script currently supports environments: 127.0.0.1, oci-vm" >&2
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
CONFIG_FILE="${CONFIG_FILE:-$ROOT_DIR/configs/${ENVIRONMENT}.json}"

service_enabled() {
  # Args: <service-name> <default:true|false>
  python3 - "$CONFIG_FILE" "$1" "$2" <<'PY'
import json
import pathlib
import sys

cfg_file = pathlib.Path(sys.argv[1])
service = sys.argv[2]
default_raw = sys.argv[3].strip().lower()
default = default_raw == "true"

if not cfg_file.is_file():
    print("true" if default else "false")
    sys.exit(0)

try:
    data = json.loads(cfg_file.read_text(encoding="utf-8"))
except Exception:
    print("true" if default else "false")
    sys.exit(0)

enabled = (
    data.get("service_overrides", {})
    .get(service, {})
    .get("enabled", default)
)

print("true" if bool(enabled) else "false")
PY
}

generate_caddyfile_127() {
  local out_file="$1"

  local ui_block=""
  if [[ "$GLOBE_LANDING_ENABLED" == "true" ]]; then
    ui_block='
	# /ui -> globe-landing static app
	handle_path /ui/* {
		reverse_proxy globe-landing:8080
	}

	# Handle `/ui` without trailing slash.
	handle_path /ui {
		reverse_proxy globe-landing:8080
	}
'
  else
    ui_block='
	# /ui is currently disabled by environment config.
	@ui path /ui*
	handle @ui {
		respond "ui disabled" 404
	}
'
  fi

  cat >"$out_file" <<EOF
:80 {
	encode zstd gzip

	# Local contract:
	# - /api/*  -> JSON/API container
	# - /auth/* -> Keycloak (OIDC provider)
	# - /ui/*   -> globe-landing (when enabled)
	# - everything else -> HTML container

	handle_path /api/* {
		reverse_proxy default-api-json:8080
	}

	# Handle \`/api\` without trailing slash.
	handle_path /api {
		reverse_proxy default-api-json:8080
	}

	@auth path /auth*
	handle @auth {
		# Use plain \`reverse_proxy\` (not \`handle_path\`) so the /auth prefix is preserved.
		reverse_proxy keycloak:8080
	}
${ui_block}
	handle {
		reverse_proxy default-html:8080
	}
}
EOF
}

generate_caddyfile_oci_vm() {
  local out_file="$1"
  local tls_line=""
  if [[ "${WC_CADDY_TLS:-auto}" == "internal" ]]; then
    tls_line=$'\n\ttls internal'
  fi

  # Comma-separated site addresses for default-html + /login (no wildcard — avoids TLS/DNS pain).
  # Default apex only; add www via WC_OCI_HTML_HOSTS=worldcliques.org, www.worldcliques.org when DNS exists.
  local html_hosts="${WC_OCI_HTML_HOSTS:-worldcliques.org}"

  local global_block=""
  if [[ -n "${WC_CADDY_ACME_EMAIL:-}" ]]; then
    global_block=$(
      cat <<GLOB
{
	email ${WC_CADDY_ACME_EMAIL}
}

GLOB
    )
  fi

  local login_block=""
  if [[ "$GLOBE_LANDING_ENABLED" == "true" ]]; then
    login_block='
	# /login without trailing slash breaks relative css/js/assets URLs — browsers request /css/... at site root
	@login_no_slash path /login
	redir @login_no_slash /login/ 308

	handle /login/* {
		uri strip_prefix /login
		reverse_proxy globe-landing:8080
	}
	handle /login/ {
		uri strip_prefix /login
		reverse_proxy globe-landing:8080
	}
'
  else
    # No /login split — requests fall through to default-html (or its 404).
    login_block=""
  fi

  cat >"$out_file" <<EOF
${global_block}# oci-vm: host + path routing on :80 and :443 (auto HTTPS when not using tls internal).
# HTML hosts: ${html_hosts} (set WC_OCI_HTML_HOSTS to add more, comma-separated).
api.worldcliques.org {${tls_line}
	encode zstd gzip
	reverse_proxy default-api-json:8080
}

auth.worldcliques.org {${tls_line}
	encode zstd gzip
	reverse_proxy keycloak:8080
}

${html_hosts} {${tls_line}
	encode zstd gzip
${login_block}
	handle {
		reverse_proxy default-html:8080
	}
}
EOF
}

generate_caddyfile() {
  local out_dir="$ROOT_DIR/.generated"
  local out_file="$out_dir/Caddyfile-${ENVIRONMENT}"
  mkdir -p "$out_dir"

  case "$ENVIRONMENT" in
    127.0.0.1)
      generate_caddyfile_127 "$out_file"
      ;;
    oci-vm)
      generate_caddyfile_oci_vm "$out_file"
      ;;
    *)
      echo "No Caddyfile generator for environment: $ENVIRONMENT" >&2
      exit 2
      ;;
  esac

  export CADDYFILE_PATH="$out_file"
}

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

DEFAULT_HTML_ENABLED="$(service_enabled "default-html" "true")"
DEFAULT_API_ENABLED="$(service_enabled "default-api-json" "true")"
GLOBE_LANDING_ENABLED="$(service_enabled "globe-landing" "false")"

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

if [[ "$DEFAULT_HTML_ENABLED" != "true" && "$DEFAULT_API_ENABLED" != "true" && "$GLOBE_LANDING_ENABLED" != "true" ]]; then
  echo "All application services are disabled by config: $CONFIG_FILE" >&2
fi

EXPECTED_IMAGES=()
if includes_manifest infra; then
  EXPECTED_IMAGES+=("local/caddy:2.8.4" "local/keycloak:26.0.5")
fi
if includes_manifest application && [[ "$DEFAULT_HTML_ENABLED" == "true" ]]; then
  EXPECTED_IMAGES+=("local/default-html:0.0.2")
fi
if includes_manifest application && [[ "$DEFAULT_API_ENABLED" == "true" ]]; then
  EXPECTED_IMAGES+=("local/default-api-json:0.0.1")
fi
if includes_manifest application && [[ "$GLOBE_LANDING_ENABLED" == "true" ]]; then
  EXPECTED_IMAGES+=("local/globe-landing:0.0.1")
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
    echo "  ./scripts/build-local.sh internal/globe-landing" >&2
  fi
  exit 2
fi

for MANIFEST_SET in "${ORDERED_MANIFESTS[@]}"; do
  COMPOSE_FILE=""
  case "$MANIFEST_SET" in
    infra)
      COMPOSE_FILE="compose/infra-${ENVIRONMENT}.yml"
      STARTED_INFRA="yes"
      generate_caddyfile
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
  if [[ "$MANIFEST_SET" == "application" ]]; then
    APP_SERVICES=()
    if [[ "$DEFAULT_HTML_ENABLED" == "true" ]]; then
      APP_SERVICES+=("default-html")
    fi
    if [[ "$DEFAULT_API_ENABLED" == "true" ]]; then
      APP_SERVICES+=("default-api-json")
    fi
    if [[ "$GLOBE_LANDING_ENABLED" == "true" ]]; then
      APP_SERVICES+=("globe-landing")
    fi
    if [[ ${#APP_SERVICES[@]} -eq 0 ]]; then
      echo "Skipping application compose up: all app services disabled in $CONFIG_FILE"
      continue
    fi
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d "${APP_SERVICES[@]}"
  else
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d
  fi
done

echo "OK"

echo
echo "==> Routes and ports ($ENVIRONMENT)"
if [[ "$STARTED_INFRA" != "yes" ]]; then
  echo "- Infra was not started; Caddy is not running."
elif [[ "$ENVIRONMENT" == "127.0.0.1" ]]; then
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
  if [[ "$GLOBE_LANDING_ENABLED" == "true" ]]; then
    echo "- Globe landing:"
    echo "  - GET http://127.0.0.1:80/ui/ -> globe-landing"
    echo "  - GET http://127.0.0.1:80/ui/* -> globe-landing"
  else
    echo "- Globe landing:"
    echo "  - GET http://127.0.0.1:80/ui/* -> 404 (disabled by config)"
  fi
elif [[ "$ENVIRONMENT" == "oci-vm" ]]; then
  echo "- Caddy: :80 (HTTP) and :443 (HTTPS); auto HTTPS unless WC_CADDY_TLS=internal"
  echo "- api.worldcliques.org -> default-api-json"
  echo "- auth.worldcliques.org -> keycloak (/auth on upstream)"
  echo "- HTML hosts (WC_OCI_HTML_HOSTS or default worldcliques.org) -> default-html"
  if [[ "$GLOBE_LANDING_ENABLED" == "true" ]]; then
    echo "- /login/ on HTML hosts -> globe-landing (/login -> 308 /login/ for correct relative assets)"
  else
    echo "- globe-landing disabled: /login handled by default-html like any other path"
  fi
fi

