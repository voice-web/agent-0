#!/usr/bin/env python3
"""Static file server without Python/uvicorn-style Server banners; adds nosniff."""

from __future__ import annotations

import http.server
import os
import socketserver

# Match default-html: inline importmap + unpkg Three.js.
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


class _StaticHandler(http.server.SimpleHTTPRequestHandler):
    def version_string(self) -> str:
        return "httpd"

    def end_headers(self) -> None:
        path_only = (self.path.split("?", 1)[0] or "").lower()
        if path_only in ("/", "/index.html", "/actor.html") or path_only.endswith(
            (".html", ".js", ".css", ".json")
        ):
            # Avoid stale globe.js / HTML after image rebuilds (browser disk cache is aggressive).
            self.send_header("Cache-Control", "no-cache, must-revalidate")
            self.send_header("Pragma", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", _CSP_HTML)
        self.send_header("Content-Security-Policy-Report-Only", _CSP_HTML)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Permissions-Policy", _PERMISSIONS_POLICY)
        self.send_header("Referrer-Policy", "strict-origin-when-cross-origin")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Strict-Transport-Security", "max-age=15552000")
        super().end_headers()


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    root = os.environ.get("GLOBE_LANDING_ROOT", "/srv/www")
    os.chdir(root)
    with socketserver.ThreadingTCPServer(("0.0.0.0", port), _StaticHandler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
