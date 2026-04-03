"""default-html — serve a default landing page + starfield-based error.html.

This container is intended for the "HTML host" (web app host).
It routes:
- GET/HEAD / -> index.html (if present)
- missing non-asset paths -> error.html (HTML-aware 404/500)
"""

from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware

_ROOT = Path(os.environ.get("BASIC_HTTP_ROOT", "/srv/www")).resolve()
_PORT = int(os.environ.get("PORT", "8080"))

_ASSET_SUFFIXES = frozenset(
    {
        ".css",
        ".js",
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".svg",
        ".ico",
        ".webp",
        ".json",
        ".map",
        ".txt",
        ".woff",
        ".woff2",
        ".ttf",
    }
)


def _is_asset_path(path: str) -> bool:
    suffix = Path(path).suffix.lower()
    return suffix in _ASSET_SUFFIXES


def _error_html_path() -> Path:
    return _ROOT / "error.html"


def _index_html_path() -> Path:
    return _ROOT / "index.html"


def _ensure_root_dir() -> Path:
    if not _ROOT.is_dir():
        raise RuntimeError(f"BASIC_HTTP_ROOT is not a directory: {_ROOT}")
    return _ROOT


def _strip_leaky_response_headers(headers) -> None:
    """MutableHeaders has no .pop() in some Starlette versions; delete by key."""
    for key in list(headers.keys()):
        if key.lower() in ("server", "x-powered-by"):
            del headers[key]


# Inline importmap + error.html inline styles; Three.js from unpkg.
_CSP_HTML = (
    "default-src 'self'; "
    "script-src 'self' 'unsafe-inline' https://unpkg.com; "
    "style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: blob:; "
    "font-src 'self'; "
    "connect-src 'self' https://unpkg.com; "
    "frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
)

_PERMISSIONS_POLICY = (
    "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
    "magnetometer=(), microphone=(), payment=(), usb=()"
)


def _set_header_if_absent(headers, name: str, value: str) -> None:
    if name.lower() not in headers:
        headers[name] = value


def _apply_browser_security_headers_html(_request: Request, response: Response) -> None:
    h = response.headers
    _strip_leaky_response_headers(h)
    _set_header_if_absent(h, "X-Content-Type-Options", "nosniff")
    _set_header_if_absent(h, "Content-Security-Policy", _CSP_HTML)
    _set_header_if_absent(h, "Content-Security-Policy-Report-Only", _CSP_HTML)
    _set_header_if_absent(h, "Cross-Origin-Opener-Policy", "same-origin")
    _set_header_if_absent(h, "Cross-Origin-Resource-Policy", "same-origin")
    _set_header_if_absent(h, "Permissions-Policy", _PERMISSIONS_POLICY)
    _set_header_if_absent(h, "Referrer-Policy", "strict-origin-when-cross-origin")
    _set_header_if_absent(h, "X-Frame-Options", "DENY")
    # Always set so scanners / direct :8080 probes see the header; UAs ignore HSTS on cleartext.
    _set_header_if_absent(h, "Strict-Transport-Security", "max-age=15552000")


app = FastAPI(title="default-html", version="0.0.1")


class _HardenResponseHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        _apply_browser_security_headers_html(request, response)
        return response


app.add_middleware(_HardenResponseHeadersMiddleware)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "root": str(_ROOT)}


@app.api_route("/", methods=["GET", "HEAD"])
async def root_dispatch(request: Request) -> Response:
    idx = _index_html_path()
    if request.method in ("GET", "HEAD") and idx.is_file():
        return FileResponse(idx)
    # If someone points the container at an empty /srv/www, give a readable error.
    err = _error_html_path()
    if err.is_file():
        return FileResponse(err, status_code=500)
    return Response(content="default-html: missing index.html and error.html", status_code=500)


@app.exception_handler(404)
async def not_found_handler(request: Request, exc) -> Response:
    # For actual asset requests, preserve simple 404 text.
    if _is_asset_path(request.url.path):
        return Response(content="Not Found", status_code=404, media_type="text/plain; charset=utf-8")

    err = _error_html_path()
    if err.is_file():
        return FileResponse(err, status_code=404)
    return Response(content="Not Found", status_code=404, media_type="text/plain; charset=utf-8")


@app.exception_handler(500)
async def server_error_handler(request: Request, exc) -> Response:
    err = _error_html_path()
    if err.is_file():
        return FileResponse(err, status_code=500)
    return Response(content="Internal Server Error", status_code=500, media_type="text/plain; charset=utf-8")


_ensure_root_dir()
app.mount("/", StaticFiles(directory=str(_ROOT), html=True), name="site")

