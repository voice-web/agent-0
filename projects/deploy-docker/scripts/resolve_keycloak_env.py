#!/usr/bin/env python3
"""Resolve a Keycloak env_file path for docker compose.

Tries in order (unless KEYCLOAK_ENV_FILE is already set — callers handle that):

1. config.json -> keycloak_env_file (if set: must exist; ~ expanded; relative paths
   are resolved under the deploy-docker project root = parent of deployments/).
2. ~/.secrets/worldcliques/<env_name>/keycloak.env
3. Fallback: any ~/.secrets/worldcliques/*/keycloak.env — prefers 127.0.0.1, then
   env_name, then local-path-127, then others sorted by directory name.

Stdout: absolute path to file. Stderr: notes when using fallback.
Exit 1 if no file found.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def _expand_config_path(raw: str, deploy_docker_root: Path) -> Path:
    p = Path(os.path.expanduser(raw.strip()))
    if not p.is_absolute():
        p = (deploy_docker_root / p).resolve()
    return p


def _pick_fallback(base: Path, env_name: str) -> Path | None:
    preferred: list[str] = []
    for name in ("127.0.0.1", env_name, "local-path-127", "oci-vm"):
        if name and name not in preferred:
            preferred.append(name)
    for name in preferred:
        cand = base / name / "keycloak.env"
        if cand.is_file():
            return cand
    rest = sorted(
        (p for p in base.glob("*/keycloak.env") if p.is_file()),
        key=lambda x: x.parent.name,
    )
    return rest[0] if rest else None


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: resolve_keycloak_env.py <deployments/.../bundle-dir>", file=sys.stderr)
        sys.exit(2)
    deploy = Path(sys.argv[1]).resolve()
    cfg_path = deploy / "config.json"
    if not cfg_path.is_file():
        print(f"Missing {cfg_path}", file=sys.stderr)
        sys.exit(2)
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    env_name = str(cfg.get("env_name") or "").strip() or "default"
    deploy_docker_root = deploy.parent.parent

    kc_cfg = (cfg.get("keycloak_env_file") or "").strip()
    if kc_cfg:
        p = _expand_config_path(kc_cfg, deploy_docker_root)
        if p.is_file():
            print(p)
            return
        print(f"config keycloak_env_file not found: {p}", file=sys.stderr)
        sys.exit(1)

    default = Path.home() / ".secrets/worldcliques" / env_name / "keycloak.env"
    if default.is_file():
        print(default.resolve())
        return

    base = Path.home() / ".secrets/worldcliques"
    if base.is_dir():
        fb = _pick_fallback(base, env_name)
        if fb is not None:
            print(
                f"==> Keycloak env_file: using {fb} (not found at {default})",
                file=sys.stderr,
            )
            print(fb.resolve())
            return

    print(f"==> Missing Keycloak env_file. Expected: {default}", file=sys.stderr)
    print(
        "Create it, set config.keycloak_env_file, or export KEYCLOAK_ENV_FILE.",
        file=sys.stderr,
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
