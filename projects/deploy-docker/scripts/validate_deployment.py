#!/usr/bin/env python3
"""HTTP smoke-test routes from a deployment's resolved.json (test_routes).

Uses the same bundle dirname as up.sh / print_routes.py. Optionally runs compile first.

Expectations (by route label):
  - Keycloak: HTTP 200 after redirects (urllib redirects by default).
  - API (default-api-json): JSON body (200 or 404 — the stub returns 404 JSON on /).
  - Default HTML / Globe*: HTML body (200).
Skips routes whose app service is listed in resolved.json but disabled (not in
application_service_names). Keycloak (edge) is always attempted.
"""
from __future__ import annotations

import argparse
import json
import ssl
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


def run_compile(root: Path, deployment_dirname: str) -> None:
    r = subprocess.run(
        [sys.executable, str(root / "scripts" / "compile.py"), deployment_dirname],
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


def _row_target_service(label: str) -> str | None:
    """App service name this row exercises, or None for edge (Keycloak)."""
    if "Keycloak" in label:
        return None
    if label.startswith("API") or "default-api-json" in label:
        return "default-api-json"
    if "Globe" in label:
        return "globe-landing"
    if "Default HTML" in label:
        return "default-html"
    if "Recon lab" in label:
        return "recon-lab"
    return None


def _should_skip_row(
    label: str,
    app_services: frozenset[str] | None,
) -> bool:
    if app_services is None:
        return False
    svc = _row_target_service(label)
    if svc is None:
        return False
    return svc not in app_services


def _check_response(label: str, status: int, headers: dict[str, str], body: bytes) -> tuple[bool, str]:
    ct = (headers.get("Content-Type") or headers.get("Content-type") or "").lower()

    if "Keycloak" in label:
        if 200 <= status < 400:
            return True, f"{status} (redirects followed)"
        return False, f"unexpected status {status}"

    if _row_target_service(label) == "default-api-json" or label.startswith("API"):
        if "application/json" in ct:
            return True, f"{status}, application/json"
        try:
            json.loads(body.decode("utf-8", errors="replace"))
            return True, f"{status}, json body"
        except json.JSONDecodeError:
            return False, f"{status}, not json"

    # HTML-ish
    if status != 200:
        return False, f"expected 200, got {status}"
    blob = body.lower()
    if b"<html" in blob or b"<!doctype" in blob or b"<head" in blob:
        return True, "200, html"
    return False, "200 but body does not look like html"


def _fetch(
    url: str,
    timeout: float,
    ssl_ctx: ssl.SSLContext | None,
    method: str = "GET",
) -> tuple[int | None, dict[str, str], bytes, str | None]:
    req = urllib.request.Request(
        url,
        method=method,
        headers={"User-Agent": "validate-deployment/1"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ssl_ctx) as resp:
            status = resp.getcode()
            hdrs = {k.lower(): v for k, v in resp.headers.items()}
            body = resp.read(65536)
            return status, hdrs, body, None
    except urllib.error.HTTPError as e:
        hdrs = {k.lower(): v for k, v in e.headers.items()} if e.headers else {}
        body = e.read(65536) if e.fp else b""
        return e.code, hdrs, body, None
    except urllib.error.URLError as e:
        return None, {}, b"", str(e.reason) if e.reason else str(e)


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(
        description="Hit test_routes from resolved.json and verify responses.",
    )
    ap.add_argument(
        "deployment_dirname",
        help="deployments/<this> name (e.g. local-ports-127) or path to resolved.json",
    )
    ap.add_argument(
        "--compile",
        action="store_true",
        help="Run compile.py before validating.",
    )
    ap.add_argument(
        "--insecure",
        action="store_true",
        help="Do not verify TLS certificates (for https / internal CAs).",
    )
    ap.add_argument(
        "--timeout",
        type=float,
        default=15.0,
        help="Per-request timeout in seconds (default: 15).",
    )
    ap.add_argument(
        "--head",
        action="store_true",
        help="Use HEAD instead of GET (stricter; some backends differ).",
    )
    args = ap.parse_args()

    raw = args.deployment_dirname
    candidate = Path(raw)

    if candidate.is_file():
        resolved = candidate.resolve()
    else:
        name = raw.strip("/").split("/")[-1] if "/" in raw else raw
        deploy_json = root / "deployments" / name / "deployment.json"
        if not deploy_json.is_file():
            print(f"Unknown deployment {raw!r} (no {deploy_json})", file=sys.stderr)
            sys.exit(2)
        resolved = resolved_path(root, name)
        if args.compile or not resolved.is_file():
            run_compile(root, name)
            resolved = resolved_path(root, name)

    try:
        data = json.loads(resolved.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"{resolved}: {e}", file=sys.stderr)
        sys.exit(1)

    rows = data.get("test_routes") or []
    if not rows:
        print("No test_routes in resolved.json; run compile.py for this bundle.", file=sys.stderr)
        sys.exit(2)

    app_names = data.get("application_service_names")
    app_set = (
        frozenset(str(x) for x in app_names)
        if isinstance(app_names, list) and app_names
        else None
    )

    ssl_ctx = None
    if args.insecure:
        ssl_ctx = ssl._create_unverified_context()

    method = "HEAD" if args.head else "GET"
    failures = 0
    skips = 0

    print(f"==> validate: {resolved}")
    print(f"    method={method}  insecure_tls={args.insecure}")

    for row in rows:
        label = str(row.get("label") or "")
        urls = [str(u) for u in (row.get("urls") or []) if u]

        if _should_skip_row(label, app_set):
            print(f"SKIP {label}  (service not in application_service_names)")
            skips += 1
            continue

        for url in urls:
            status, hdrs, body, err = _fetch(url, args.timeout, ssl_ctx, method=method)
            if err:
                print(f"FAIL {label}")
                print(f"     {url}")
                print(f"     error: {err}")
                failures += 1
                continue
            assert status is not None
            if args.head:
                ok = status < 500
                detail = f"{status} (HEAD only — status < 500)"
            else:
                ok, detail = _check_response(label, status, hdrs, body)
            status_chr = "OK  " if ok else "FAIL"
            print(f"{status_chr}{label}")
            print(f"     {url}")
            print(f"     {detail}")
            if not ok:
                failures += 1

    print()
    if failures:
        print(f"==> {failures} check(s) failed ({skips} skipped)", file=sys.stderr)
        sys.exit(1)
    print(f"==> all checks passed ({skips} skipped)")
    sys.exit(0)


if __name__ == "__main__":
    main()
