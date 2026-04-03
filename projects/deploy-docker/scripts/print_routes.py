#!/usr/bin/env python3
"""Print test_routes from a deployment's resolved.json (produced by compile.py).

Same deployment arguments as up.sh, e.g.:
  print_routes.py 127.0.0.1
  print_routes.py local-path-127
  print_routes.py oci-vm

You can still pass a path to resolved.json if it exists (legacy).
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


def map_deployment_id(raw: str) -> str:
    aliases = {
        "127.0.0.1": "local-path-127",
        "oci-vm": "vm-host-oci",
    }
    return aliases.get(raw, raw)


def sanitize(s: str) -> str:
    """Match scripts/compile.py (output directory naming)."""
    s = s.lower().replace(".", "-")
    return re.sub(r"[^a-z0-9_-]+", "-", s).strip("-") or "deploy"


def resolved_path_for_deployment(root: Path, deployment_bundle_id: str) -> Path:
    deploy_dir = root / "deployments" / deployment_bundle_id
    meta = json.loads((deploy_dir / "deployment.json").read_text(encoding="utf-8"))
    deployment_id = str(meta["deployment_id"])
    return root / ".generated" / sanitize(deployment_id) / "resolved.json"


def run_compile(root: Path, deployment_bundle_id: str) -> None:
    compile_py = root / "scripts" / "compile.py"
    r = subprocess.run(
        [sys.executable, str(compile_py), deployment_bundle_id],
        cwd=str(root),
        check=False,
    )
    if r.returncode != 0:
        sys.exit(r.returncode)


def print_routes_from_resolved(path: Path) -> None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"{path}: {e}", file=sys.stderr)
        sys.exit(1)
    rows = data.get("test_routes") or []
    if not rows:
        return
    print()
    print("==> Routes (curl or browser)")
    for row in rows:
        label = row.get("label", "")
        for u in row.get("urls") or []:
            print(f"    {label}: {u}")


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(
        description="Print route URLs from a deployment bundle (same names as up.sh).",
    )
    ap.add_argument(
        "deployment",
        help="Deployment id or alias (127.0.0.1, oci-vm, local-path-127, …), "
        "or path to resolved.json if that file exists.",
    )
    ap.add_argument(
        "--compile",
        action="store_true",
        help="Run compile.py before printing (refresh resolved.json).",
    )
    args = ap.parse_args()
    raw = args.deployment
    candidate = Path(raw)

    if candidate.is_file():
        print_routes_from_resolved(candidate.resolve())
        return

    bundle_id = map_deployment_id(raw)
    deploy_dir = root / "deployments" / bundle_id
    if not (deploy_dir / "deployment.json").is_file():
        print(
            f"Unknown deployment {raw!r} (no {deploy_dir / 'deployment.json'})",
            file=sys.stderr,
        )
        sys.exit(2)

    resolved = resolved_path_for_deployment(root, bundle_id)
    if args.compile or not resolved.is_file():
        run_compile(root, bundle_id)
    if not resolved.is_file():
        print(f"Not found after compile: {resolved}", file=sys.stderr)
        sys.exit(1)
    print_routes_from_resolved(resolved)


if __name__ == "__main__":
    main()
