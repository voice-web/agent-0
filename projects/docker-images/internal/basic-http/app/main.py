"""Serve files from BASIC_HTTP_ROOT, or echo the request as JSON when no index.html."""
from __future__ import annotations

import base64
import json
import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

_ROOT = Path(os.environ.get("BASIC_HTTP_ROOT", "/srv/www")).resolve()
_MAX_BODY = int(os.environ.get("BASIC_HTTP_MAX_BODY_DUMP", "1048576"))  # 1 MiB

_ROOT_METHODS = frozenset(
    {"GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"}
)


def _ensure_root() -> Path:
    if not _ROOT.is_dir():
        raise RuntimeError(
            f"BASIC_HTTP_ROOT is not a directory: {_ROOT} "
            "(mount a host folder to /srv/www in compose, or create the path)"
        )
    return _ROOT


def _headers_for_json(request: Request) -> list[list[str]]:
    out: list[list[str]] = []
    for key_b, val_b in request.headers.raw:
        out.append(
            [
                key_b.decode("iso-8859-1"),
                val_b.decode("iso-8859-1"),
            ]
        )
    return out


def _client_ip_block(request: Request) -> dict:
    """TCP peer vs forwarded client (browser) when behind Caddy/nginx/Docker."""
    peer = None
    if request.client:
        peer = {"host": request.client.host, "port": request.client.port}

    h = request.headers
    xff_raw = h.get("x-forwarded-for")
    chain: list[str] = []
    if xff_raw:
        chain = [p.strip() for p in xff_raw.split(",") if p.strip()]

    x_real = h.get("x-real-ip")
    if x_real:
        x_real = x_real.strip()

    # First hop in X-Forwarded-For is typically the original client (if chain is trusted).
    from_xff = chain[0] if chain else None
    best = from_xff or x_real or (peer["host"] if peer else None)

    return {
        "peer": peer,
        "x_forwarded_for_raw": xff_raw,
        "x_forwarded_for_chain": chain,
        "x_real_ip": x_real,
        "forwarded_header_raw": h.get("forwarded"),
        "best_effort_remote_ip": best,
    }


def _service_identity() -> dict:
    """Set per container in compose so JSON echo shows which backend handled the request."""
    return {
        "basic_http_instance": os.environ.get("BASIC_HTTP_INSTANCE"),
        "basic_http_public_path": os.environ.get("BASIC_HTTP_PUBLIC_PATH"),
        "container_hostname": os.environ.get("HOSTNAME"),
    }


app = FastAPI(title="basic-http", version="0.0.5")


@app.get("/health")
def health() -> dict[str, str | None]:
    out: dict[str, str | None] = {"status": "ok", "root": str(_ROOT)}
    out.update(_service_identity())
    return out


async def _request_dump(request: Request) -> dict:
    body = await request.body()
    truncated = len(body) > _MAX_BODY
    snippet = body[:_MAX_BODY] if truncated else body

    body_text: str | None
    body_b64: str | None
    try:
        body_text = snippet.decode("utf-8")
        body_b64 = None
    except UnicodeDecodeError:
        body_text = None
        body_b64 = base64.b64encode(snippet).decode("ascii")

    ip_block = _client_ip_block(request)
    return {
        "mode": "request_echo",
        "service": _service_identity(),
        "method": request.method,
        "url": str(request.url),
        "path": request.url.path,
        "query": dict(request.query_params),
        "headers": _headers_for_json(request),
        "cookies": dict(request.cookies),
        "client_ip": ip_block,
        # Same as client_ip.peer (immediate TCP peer — often Docker bridge / reverse proxy).
        "client": ip_block["peer"],
        "body": {
            "length": len(body),
            "truncated": truncated,
            "max_dump_bytes": _MAX_BODY,
            "utf8": body_text,
            "base64": body_b64,
        },
    }


@app.api_route("/", methods=sorted(_ROOT_METHODS))
async def root_dispatch(request: Request) -> Response:
    """If index.html exists, serve it for GET/HEAD; otherwise JSON dump of this request."""
    idx = _ROOT / "index.html"
    if request.method in ("GET", "HEAD") and idx.is_file():
        return FileResponse(idx)

    payload = await _request_dump(request)
    body = json.dumps(payload, default=str, indent=2).encode("utf-8")
    headers = {
        "content-type": "application/json; charset=utf-8",
        "content-length": str(len(body)),
    }
    if request.method == "HEAD":
        return Response(status_code=200, headers=headers)
    return Response(content=body, status_code=200, headers=headers)


_root = _ensure_root()
app.mount("/", StaticFiles(directory=str(_root), html=True), name="site")
