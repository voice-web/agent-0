#!/usr/bin/env python3
"""Resolve filesystem paths for a deployment bundle.

A bundle is the directory name under deployments/, e.g. local-path-127.
Output dir under .generated/ uses deployment_id from deployment.json + the same
sanitize rules as compile.py.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def sanitize(s: str) -> str:
    s = s.lower().replace(".", "-")
    return re.sub(r"[^a-z0-9_-]+", "-", s).strip("-") or "deploy"


def bundle_root(dirname: str) -> Path:
    return ROOT / "deployments" / dirname


def generated_root_for_bundle(dirname: str) -> Path:
    d = bundle_root(dirname)
    if not (d / "deployment.json").is_file():
        print(f"Unknown deployment {dirname!r} (no {d / 'deployment.json'})", file=sys.stderr)
        sys.exit(2)
    meta = json.loads((d / "deployment.json").read_text(encoding="utf-8"))
    return ROOT / ".generated" / sanitize(str(meta["deployment_id"]))


def main() -> None:
    if len(sys.argv) != 3 or sys.argv[1] != "gendir":
        print("Usage: bundle_paths.py gendir <deployment-dirname>", file=sys.stderr)
        sys.exit(2)
    print(generated_root_for_bundle(sys.argv[2]))


if __name__ == "__main__":
    main()
