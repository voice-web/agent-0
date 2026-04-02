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


app = FastAPI(title="default-api-json", version="0.0.1")

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

