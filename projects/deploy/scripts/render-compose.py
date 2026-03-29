#!/usr/bin/env python3
"""Generate docker-compose.yml from docker-compose.template.yml + versions.manifest.json."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "versions.manifest.json"
TEMPLATE_PATH = ROOT / "docker-compose.template.yml"
OUTPUT_PATH = ROOT / "docker-compose.yml"


def _load_manifest() -> dict:
    data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    ver = data.get("schema_version")
    if ver != 1:
        sys.exit(f"unsupported schema_version: {ver!r} (expected 1)")
    components = data.get("components")
    if not isinstance(components, dict):
        sys.exit("manifest missing 'components' object")
    return data


def _substitutions(components: dict) -> dict[str, str]:
    try:
        caddy = components["caddy"]["image"]
        basic = components["basic_http"]["image"]
    except KeyError as e:
        sys.exit(f"manifest components missing required key: {e}")
    return {
        "IMAGE_CADDY": caddy,
        "IMAGE_BASIC_HTTP": basic,
    }


def render() -> str:
    data = _load_manifest()
    mapping = _substitutions(data["components"])
    text = TEMPLATE_PATH.read_text(encoding="utf-8")
    for key, val in mapping.items():
        text = text.replace("{{" + key + "}}", val)
    unresolved = set(re.findall(r"\{\{(\w+)\}\}", text))
    if unresolved:
        sys.exit(f"unresolved template placeholders: {sorted(unresolved)}")
    return text


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 0 only if docker-compose.yml already matches render output",
    )
    args = parser.parse_args()
    out = render()
    if args.check:
        if not OUTPUT_PATH.is_file():
            sys.exit("docker-compose.yml missing (run without --check)")
        current = OUTPUT_PATH.read_text(encoding="utf-8")
        if current != out:
            sys.exit("docker-compose.yml is out of date; run scripts/render-compose.py")
        print("OK: docker-compose.yml matches manifest + template")
        return
    OUTPUT_PATH.write_text(out, encoding="utf-8", newline="\n")
    print(f"wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
