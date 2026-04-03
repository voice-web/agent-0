#!/usr/bin/env bash
# Run up.sh for deployment(s) whose deployments/<id>/services.json changed vs a git base ref.
# (Recompiles and applies compose — same as a manual ./scripts/up.sh <id>.)
#
# Usage:
#   ./scripts/deploy-changed.sh [--dry-run] [--deployment <id>] [--force] [<base-ref>]
#
# Without --deployment: every deployment under deployments/ whose services.json changed.
# With --deployment <id>: only that id, and only if its services.json changed, unless --force
# (then up.sh runs for that id regardless of git diff).
#
# <base-ref> defaults to main, then origin/main, then HEAD~1 (first that exists).
# Changed paths = unstaged and staged diffs against <base-ref> (git diff --name-only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UP_SH="$ROOT/scripts/up.sh"

DRY_RUN=false
FORCE=false
DEPLOY_FILTER=""
BASE_REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --deployment)
      DEPLOY_FILTER="${2:-}"
      if [[ -z "$DEPLOY_FILTER" ]]; then
        echo "error: --deployment requires an argument" >&2
        exit 2
      fi
      shift 2
      ;;
    -h | --help)
      sed -n '1,25p' "$0" | tail -n +2
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

if [[ "$FORCE" == true && -z "$DEPLOY_FILTER" ]]; then
  echo "error: --force requires --deployment <id>" >&2
  exit 2
fi

if [[ ! -f "$UP_SH" ]]; then
  echo "error: missing $UP_SH" >&2
  exit 1
fi

REPO_ROOT="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: $ROOT is not inside a git repository" >&2
  exit 1
}

case "$ROOT" in
  "$REPO_ROOT" | "$REPO_ROOT"/*) ;;
  *)
    echo "error: deploy-docker root is not under git toplevel: $ROOT" >&2
    exit 1
    ;;
esac

REL="${ROOT#"$REPO_ROOT"/}"
if [[ "$REL" == "$ROOT" ]]; then
  REL="."
fi

if [[ -z "$BASE_REF" && "$FORCE" != true ]]; then
  if git -C "$REPO_ROOT" rev-parse --verify main >/dev/null 2>&1; then
    BASE_REF=main
  elif git -C "$REPO_ROOT" rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE_REF=origin/main
  else
    BASE_REF=HEAD~1
  fi
fi

if [[ "$FORCE" != true ]]; then
  if ! git -C "$REPO_ROOT" rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    echo "error: not a valid git ref: $BASE_REF" >&2
    exit 1
  fi
fi

tmpd="$(mktemp -d)"
trap 'rm -rf "$tmpd"' EXIT

if [[ "$FORCE" == true ]]; then
  dep="$DEPLOY_FILTER"
  if [[ ! -f "$ROOT/deployments/$dep/deployment.json" ]]; then
    echo "error: unknown deployment '$dep' (no deployments/$dep/deployment.json)" >&2
    exit 2
  fi
  if [[ ! -f "$ROOT/deployments/$dep/services.json" ]]; then
    echo "error: missing deployments/$dep/services.json" >&2
    exit 2
  fi
  echo "$dep" >"$tmpd/deps"
else
  {
    git -C "$REPO_ROOT" diff --name-only "$BASE_REF"
    git -C "$REPO_ROOT" diff --name-only --cached "$BASE_REF"
  } | sort -u >"$tmpd/files"

  : >"$tmpd/deps"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    dep=""
    if [[ "$REL" == "." ]]; then
      case "$line" in
        deployments/*/services.json)
          rest="${line#deployments/}"
          dep="${rest%%/services.json}"
          ;;
        *) continue ;;
      esac
    else
      case "$line" in
        "$REL"/deployments/*/services.json)
          rest="${line#"$REL"/deployments/}"
          dep="${rest%%/services.json}"
          ;;
        *) continue ;;
      esac
    fi
    if [[ -z "$dep" ]]; then
      continue
    fi
    if [[ -n "$DEPLOY_FILTER" && "$dep" != "$DEPLOY_FILTER" ]]; then
      continue
    fi
    if [[ -f "$ROOT/deployments/$dep/deployment.json" && -f "$ROOT/deployments/$dep/services.json" ]]; then
      echo "$dep" >>"$tmpd/deps"
    fi
  done <"$tmpd/files"

  sort -u -o "$tmpd/deps" "$tmpd/deps"
fi

if [[ ! -s "$tmpd/deps" ]]; then
  if [[ -n "$DEPLOY_FILTER" && "$FORCE" != true ]]; then
    echo "No changes vs $BASE_REF for deployments/$DEPLOY_FILTER/services.json."
  elif [[ -n "$DEPLOY_FILTER" ]]; then
    echo "error: internal: empty deps with --force" >&2
    exit 1
  else
    echo "No deployments with services.json changes vs $BASE_REF (under ${REL}/deployments/)."
  fi
  exit 0
fi

n="$(wc -l <"$tmpd/deps" | tr -d ' ')"
list="$(paste -sd' ' "$tmpd/deps")"
if [[ "$FORCE" == true ]]; then
  echo "Deployment: $list (--force, skipping git diff)"
else
  echo "Base ref: $BASE_REF"
  echo "Deploying $n stack(s): $list"
fi
echo

while IFS= read -r dep; do
  [[ -n "$dep" ]] || continue
  if $DRY_RUN; then
    echo "[dry-run] $UP_SH $dep"
  else
    "$UP_SH" "$dep"
  fi
done <"$tmpd/deps"
