#!/usr/bin/env bash
# Build docker images under internal/* and external/* that have git changes vs a base ref.
# Invokes scripts/build-local.sh for each affected image (directory with Dockerfile + version.txt).
#
# Usage:
#   ./scripts/build-changed.sh [--dry-run] [<base-ref>]
#
# <base-ref> defaults to main, then origin/main, then HEAD~1 (in that order, first that exists).
# Changed paths = unstaged and staged diffs against <base-ref> (see git diff --name-only).
#
# Env: same as build-local.sh (IMAGE_PREFIX, IMAGE_NAME, DOCKER).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_LOCAL="$ROOT/scripts/build-local.sh"

DRY_RUN=false
BASE_REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h | --help)
      sed -n '1,20p' "$0" | tail -n +2
      exit 0
      ;;
    -*)
      echo "unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -n "$BASE_REF" ]]; then
        echo "error: unexpected argument: $1" >&2
        exit 1
      fi
      BASE_REF="$1"
      shift
      ;;
  esac
done

if [[ ! -f "$BUILD_LOCAL" ]]; then
  echo "error: missing $BUILD_LOCAL" >&2
  exit 1
fi

REPO_ROOT="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: $ROOT is not inside a git repository" >&2
  exit 1
}

case "$ROOT" in
  "$REPO_ROOT" | "$REPO_ROOT"/*) ;;
  *)
    echo "error: docker-images root is not under git toplevel: $ROOT" >&2
    exit 1
    ;;
esac

REL="${ROOT#"$REPO_ROOT"/}"
if [[ "$REL" == "$ROOT" ]]; then
  REL="."
fi

if [[ -z "$BASE_REF" ]]; then
  if git -C "$REPO_ROOT" rev-parse --verify main >/dev/null 2>&1; then
    BASE_REF=main
  elif git -C "$REPO_ROOT" rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE_REF=origin/main
  else
    BASE_REF=HEAD~1
  fi
fi

if ! git -C "$REPO_ROOT" rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "error: not a valid git ref: $BASE_REF" >&2
  exit 1
fi

tmpd="$(mktemp -d)"
trap 'rm -rf "$tmpd"' EXIT

{
  git -C "$REPO_ROOT" diff --name-only "$BASE_REF"
  git -C "$REPO_ROOT" diff --name-only --cached "$BASE_REF"
} | sort -u >"$tmpd/files"

: >"$tmpd/svcs"
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -n "$line" ]] || continue
  if [[ "$REL" == "." ]]; then
    case "$line" in
      internal/* | external/*) suffix="$line" ;;
      *) continue ;;
    esac
  else
    case "$line" in
      "$REL"/internal/* | "$REL"/external/*) suffix="${line#"$REL"/}" ;;
      *) continue ;;
    esac
  fi

  IFS=/ read -r seg1 seg2 _ <<<"$suffix"
  if [[ "$seg1" != "internal" && "$seg1" != "external" ]]; then
    continue
  fi
  if [[ -z "$seg2" ]]; then
    continue
  fi

  svc="$seg1/$seg2"
  svc_path="$ROOT/$svc"
  if [[ -f "$svc_path/Dockerfile" && -f "$svc_path/version.txt" ]]; then
    echo "$svc" >>"$tmpd/svcs"
  fi
done <"$tmpd/files"

sort -u -o "$tmpd/svcs" "$tmpd/svcs"

if [[ ! -s "$tmpd/svcs" ]]; then
  echo "No image directories with changes vs $BASE_REF (under ${REL}/{internal,external}/)."
  exit 0
fi

n="$(wc -l <"$tmpd/svcs" | tr -d ' ')"
list="$(paste -sd' ' "$tmpd/svcs")"
echo "Base ref: $BASE_REF"
echo "Building $n image(s): $list"
echo

while IFS= read -r svc; do
  [[ -n "$svc" ]] || continue
  if $DRY_RUN; then
    echo "[dry-run] $BUILD_LOCAL $svc"
  else
    "$BUILD_LOCAL" "$svc"
  fi
done <"$tmpd/svcs"
