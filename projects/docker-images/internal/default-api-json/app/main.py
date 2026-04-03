"""default-api-json — JSON-only stub for the API host.

This is meant to support early routing + proxy behavior:
- Always returns JSON for errors (404/500).
- Provides a predictable CORS baseline so an SPA can call the API with
  Authorization: Bearer <token> without cookie concerns.
"""

from __future__ import annotations

import os
from typing import Any

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from starlette.middleware.base import BaseHTTPMiddleware

_PORT = int(os.environ.get("PORT", "8080"))


def _split_csv(s: str) -> list[str]:
    return [p.strip() for p in s.split(",") if p.strip()]


def _cors_origins() -> list[str]:
    raw = os.environ.get("CORS_ALLOW_ORIGINS", "*").strip()
    if raw == "*":
        return ["*"]
    return _split_csv(raw)


def _cors_allow_headers() -> list[str]:
    raw = os.environ.get("CORS_ALLOW_HEADERS", "Authorization,Content-Type").strip()
    return _split_csv(raw)


def _strip_leaky_response_headers(headers) -> None:
    """MutableHeaders has no .pop() in some Starlette versions; delete by key."""
    for key in list(headers.keys()):
        if key.lower() in ("server", "x-powered-by"):
            del headers[key]


_CSP_API = "default-src 'none'; frame-ancestors 'none'"

_PERMISSIONS_POLICY = (
    "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
    "magnetometer=(), microphone=(), payment=(), usb=()"
)


def _set_header_if_absent(headers, name: str, value: str) -> None:
    if name.lower() not in headers:
        headers[name] = value


def _apply_browser_security_headers_api(_request: Request, response: Response) -> None:
    h = response.headers
    _strip_leaky_response_headers(h)
    _set_header_if_absent(h, "X-Content-Type-Options", "nosniff")
    _set_header_if_absent(h, "Content-Security-Policy", _CSP_API)
    _set_header_if_absent(h, "Content-Security-Policy-Report-Only", _CSP_API)
    _set_header_if_absent(h, "Cross-Origin-Opener-Policy", "same-origin")
    # Public JSON + CORS: allow cross-origin reads without CORP blocking fetch.
    _set_header_if_absent(h, "Cross-Origin-Resource-Policy", "cross-origin")
    _set_header_if_absent(h, "Permissions-Policy", _PERMISSIONS_POLICY)
    _set_header_if_absent(h, "Referrer-Policy", "strict-origin-when-cross-origin")
    _set_header_if_absent(h, "X-Frame-Options", "DENY")
    # Always set so probes see HSTS; UAs ignore it on cleartext.
    _set_header_if_absent(h, "Strict-Transport-Security", "max-age=15552000")


app = FastAPI(title="default-api-json", version="0.0.1")


class _HardenResponseHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        _apply_browser_security_headers_api(request, response)
        return response


app.add_middleware(_HardenResponseHeadersMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_credentials=False,  # tokens via Authorization header; avoid cookie semantics
    allow_methods=["*"],
    allow_headers=_cors_allow_headers(),
)


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok"}


@app.exception_handler(500)
async def server_error_handler(request: Request, exc) -> Response:
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "Internal Server Error",
            }
        },
    )


@app.api_route(
    "/{path:path}",
    methods=[
        "GET",
        "POST",
        "PUT",
        "PATCH",
        "DELETE",
        "OPTIONS",
        "HEAD",
    ],
)
async def catch_all(request: Request, path: str) -> Response:
    # For now, keep it explicit and debuggable rather than echoing.
    # Downstream API services will replace this stub.
    return JSONResponse(
        status_code=404,
        content={
            "error": {
                "code": "NOT_FOUND",
                "message": "API route not found on this container.",
                "path": path,
                "method": request.method,
            }
        },
    )

