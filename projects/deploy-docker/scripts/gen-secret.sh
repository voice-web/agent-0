#!/usr/bin/env bash
set -euo pipefail

# Generates random, human-readable credentials for a given logical secret type.
# Currently supported:
#   gen-secret.sh keycloak

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 keycloak" >&2
  exit 2
fi

SECRET_KIND="$1"
if [[ "$SECRET_KIND" != "keycloak" ]]; then
  echo "Only supported kind for now: keycloak" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"

# Discover available environments from compose files: infra-<env>.yml
ENVIRONMENTS=()
if compgen -G "$COMPOSE_DIR/infra-*.yml" >/dev/null 2>&1; then
  for f in "$COMPOSE_DIR"/infra-*.yml; do
    base="$(basename "$f")" # infra-127.0.0.1.yml
    env="${base#infra-}"
    env="${env%.yml}"
    ENVIRONMENTS+=("$env")
  done
fi

if [[ ${#ENVIRONMENTS[@]} -eq 0 ]]; then
  ENVIRONMENTS=("127.0.0.1")
fi

echo "Select environment:"
idx=1
for e in "${ENVIRONMENTS[@]}"; do
  echo "  $idx) $e"
  idx=$((idx + 1))
done

read -r -p "Enter choice [1-${#ENVIRONMENTS[@]}]: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
  echo "Invalid choice: $choice" >&2
  exit 2
fi
if ((choice < 1 || choice > ${#ENVIRONMENTS[@]})); then
  echo "Choice out of range: $choice" >&2
  exit 2
fi

ENVIRONMENT="${ENVIRONMENTS[$((choice - 1))]}"

SECRETS_DIR="${SECRETS_DIR:-$HOME/.secrets/worldcliques/$ENVIRONMENT}"
OUT_FILE="$SECRETS_DIR/keycloak.env"

mkdir -p "$(dirname "$OUT_FILE")"
if [[ -f "$OUT_FILE" ]]; then
  read -r -p "Secret file exists: $OUT_FILE. Overwrite? [y/N]: " overwrite
  overwrite="${overwrite:-N}"
  if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
    echo "Aborted; keeping existing file." >&2
    exit 1
  fi
fi

# Generate credentials (ASCII only).
#
# Username: a few readable tokens + digits
# Password: 32 chars from a strong set including symbols
CREDS="$(python3 - <<'PY'
import random
import secrets

adjectives = [
    "bright","calm","swift","gentle","quick","lucky","honest","steady","bold","silent",
    "brightest","classic","modern","radiant","sunny","stormy","silver","golden",
]
nouns = [
    "eagle","falcon","otter","pine","cedar","ember","orbit","comet","lantern","harbor",
    "atlas","kestrel","river","mountain","canyon","shadow","meadow","summit","horizon",
]

username = f"wc-{random.choice(adjectives)}-{random.choice(nouns)}-{secrets.randbelow(9000)+1000}"

alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
symbols = "!@#$%^&*()-_=+[]{};:,.?~"
all_chars = alphabet + symbols

length = 32
password = "".join(secrets.choice(all_chars) for _ in range(length))

print(username)
print(password)
PY
)"

KEYCLOAK_ADMIN="$(echo "$CREDS" | sed -n '1p')"
KEYCLOAK_ADMIN_PASSWORD="$(echo "$CREDS" | sed -n '2p')"

cat >"$OUT_FILE" <<EOF
KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN
KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD
EOF

chmod 600 "$OUT_FILE"

echo "OK"
echo "Wrote: $OUT_FILE"
echo "KEYCLOAK_ADMIN: $KEYCLOAK_ADMIN"
echo "KEYCLOAK_ADMIN_PASSWORD: (stored; shown below for convenience)"
echo "$KEYCLOAK_ADMIN_PASSWORD"

