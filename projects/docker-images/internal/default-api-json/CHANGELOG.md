# Changelog

## [0.0.5] - 2026-04-03
- Always send `Strict-Transport-Security` on responses (see default-html 0.0.8 changelog).

## [0.0.4] - 2026-04-03
- Browser security headers: tight JSON CSP (+ report-only), COOP, CORP `cross-origin` (CORS-friendly), Permissions-Policy, Referrer-Policy, X-Frame-Options; HSTS when HTTPS / `X-Forwarded-Proto: https`.

## [0.0.3] - 2026-04-03
- Fix response hardening middleware: Starlette `MutableHeaders` has no `pop()` in some versions; remove `server` / `x-powered-by` by key iteration instead.

## [0.0.2] - 2026-04-03
- Run uvicorn with `--no-server-header` and strip residual `Server` / `X-Powered-By` in middleware; set `X-Content-Type-Options: nosniff` when absent.

## [0.0.1] - 2026-04-02
- New `default-api-json` image: JSON-only stub + CORS + JSON error payloads.

