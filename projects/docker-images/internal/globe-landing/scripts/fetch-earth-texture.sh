#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="$ROOT_DIR/site/assets/earth-equirect.jpg"

mkdir -p "$(dirname "$OUT_FILE")"

curl -fsSL -o "$OUT_FILE" \
  "https://raw.githubusercontent.com/mrdoob/three.js/r152/examples/textures/planets/earth_atmos_2048.jpg"

echo "Wrote: $OUT_FILE"

