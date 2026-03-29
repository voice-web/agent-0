#!/usr/bin/env bash
# Build a docker image from external/<name> or internal/<name>.
# version.txt: for external/* use the upstream version (e.g. 2.8.4, 26.0.5, v0.8.12);
#              for internal/* use your semver (e.g. 0.0.1).
# Usage: ./scripts/build-local.sh external/caddy
# Env:
#   IMAGE_PREFIX   default: local
#   IMAGE_NAME     default: basename of service dir (e.g. caddy)
#   DOCKER         default: docker
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SERVICE_PATH="${1:?usage: $0 <path e.g. external/caddy>}"
[[ -d "$SERVICE_PATH" ]] || { echo "error: not a directory: $SERVICE_PATH" >&2; exit 1; }
[[ -f "$SERVICE_PATH/Dockerfile" ]] || { echo "error: missing $SERVICE_PATH/Dockerfile" >&2; exit 1; }
[[ -f "$SERVICE_PATH/version.txt" ]] || { echo "error: missing $SERVICE_PATH/version.txt" >&2; exit 1; }

VERSION="$(tr -d ' \t\r\n' <"$SERVICE_PATH/version.txt")"
[[ -n "$VERSION" ]] || { echo "error: empty version in $SERVICE_PATH/version.txt" >&2; exit 1; }

IMAGE_PREFIX="${IMAGE_PREFIX:-local}"
SERVICE_BASENAME="$(basename "$SERVICE_PATH")"
IMAGE_NAME="${IMAGE_NAME:-$SERVICE_BASENAME}"
DOCKER="${DOCKER:-docker}"

TAG="${IMAGE_PREFIX}/${IMAGE_NAME}:${VERSION}"

echo "==> build context: $SERVICE_PATH"
echo "==> tag: $TAG"
$DOCKER build -t "$TAG" -f "$SERVICE_PATH/Dockerfile" "$SERVICE_PATH"
echo "OK: $TAG"
