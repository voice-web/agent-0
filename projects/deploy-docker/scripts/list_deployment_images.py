#!/usr/bin/env python3
"""List Docker images declared in each deployments/*/services.json.

Prints:
  1) Per deployment: service name, image reference (edge then application stacks).
  2) A sorted list of unique image references (what you need locally / in a registry).

Usage:
  ./scripts/list_deployment_images.py
  ./scripts/list_deployment_images.py /path/to/projects/deploy-docker
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _services_entries(data: dict) -> list[tuple[str, str, str]]:
    """Return (stack, service_name, image) for edge and application lists."""
    out: list[tuple[str, str, str]] = []
    for stack in ("edge", "application"):
        items = data.get(stack)
        if not isinstance(items, list):
            continue
        for row in items:
            if not isinstance(row, dict):
                continue
            name = str(row.get("name") or "?")
            img = row.get("image")
            if not img:
                continue
            out.append((stack, name, str(img).strip()))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument(
        "deploy_root",
        nargs="?",
        default=None,
        help="Path to deploy-docker repo root (parent of deployments/). Default: script/../..",
    )
    args = ap.parse_args()

    if args.deploy_root:
        root = Path(args.deploy_root).resolve()
    else:
        root = Path(__file__).resolve().parent.parent

    deployments_dir = root / "deployments"
    if not deployments_dir.is_dir():
        print(f"No deployments directory: {deployments_dir}", file=sys.stderr)
        sys.exit(2)

    bundles: list[tuple[str, list[tuple[str, str, str]]]] = []
    all_images: set[str] = set()

    for child in sorted(deployments_dir.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir():
            continue
        svc_path = child / "services.json"
        if not svc_path.is_file():
            continue
        try:
            data = json.loads(svc_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as e:
            print(f"SKIP {child.name}: {svc_path}: {e}", file=sys.stderr)
            continue
        if not isinstance(data, dict):
            continue
        entries = _services_entries(data)
        if not entries:
            continue
        bundles.append((child.name, entries))
        for _stack, _name, img in entries:
            all_images.add(img)

    for name, entries in bundles:
        print(f"==> {name}")
        for stack, svc, img in entries:
            print(f"    [{stack:12}] {svc:22} {img}")
        print()

    print("==> Unique images (build / docker pull these references)")
    for img in sorted(all_images, key=str.lower):
        print(f"    {img}")

    print()
    print(f"    ({len(all_images)} unique image reference(s) across {len(bundles)} deployment(s))")


if __name__ == "__main__":
    main()
