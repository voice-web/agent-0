#!/usr/bin/env python3
"""Print test_routes from a deployment's resolved.json (produced by compile.py).

Takes the same <deployment-dirname> as up.sh — the directory name under deployments/,
e.g. local-path-127, vm-host-oci.

You can still pass an absolute path to resolved.json if that file exists.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run_compile(root: Path, deployment_dirname: str) -> None:
    compile_py = root / "scripts" / "compile.py"
    r = subprocess.run(
        [sys.executable, str(compile_py), deployment_dirname],
        cwd=str(root),
        check=False,
    )
    if r.returncode != 0:
        sys.exit(r.returncode)


def resolved_path(root: Path, deployment_dirname: str) -> Path:
    r = subprocess.run(
        [
            sys.executable,
            str(root / "scripts" / "bundle_paths.py"),
            "gendir",
            deployment_dirname,
        ],
        cwd=str(root),
        capture_output=True,
        text=True,
        check=False,
    )
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        sys.exit(2)
    return Path(r.stdout.strip()) / "resolved.json"


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
        description="Print route URLs for a deployment bundle (directory name under deployments/).",
    )
    ap.add_argument(
        "deployment_dirname",
        help="Name of deployments/<this> (e.g. local-path-127), or path to resolved.json.",
    )
    ap.add_argument(
        "--compile",
        action="store_true",
        help="Run compile.py before printing (refresh resolved.json).",
    )
    args = ap.parse_args()
    raw = args.deployment_dirname
    candidate = Path(raw)

    if candidate.is_file():
        print_routes_from_resolved(candidate.resolve())
        return

    name = raw.strip("/").split("/")[-1] if "/" in raw else raw
    deploy_json = root / "deployments" / name / "deployment.json"
    if not deploy_json.is_file():
        print(
            f"Unknown deployment {raw!r} (no {deploy_json})",
            file=sys.stderr,
        )
        sys.exit(2)

    resolved = resolved_path(root, name)
    if args.compile or not resolved.is_file():
        run_compile(root, name)
        resolved = resolved_path(root, name)
    if not resolved.is_file():
        print(f"Not found after compile: {resolved}", file=sys.stderr)
        sys.exit(1)
    print_routes_from_resolved(resolved)


if __name__ == "__main__":
    main()
