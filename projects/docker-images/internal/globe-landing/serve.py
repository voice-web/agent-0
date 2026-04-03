#!/usr/bin/env python3
"""Static file server without Python/uvicorn-style Server banners; adds nosniff."""

from __future__ import annotations

import http.server
import os
import socketserver


class _StaticHandler(http.server.SimpleHTTPRequestHandler):
    def version_string(self) -> str:
        return "httpd"

    def end_headers(self) -> None:
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    root = os.environ.get("GLOBE_LANDING_ROOT", "/srv/www")
    os.chdir(root)
    with socketserver.ThreadingTCPServer(("0.0.0.0", port), _StaticHandler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
