# Changelog

## [0.0.8] - 2026-04-03
- Always send `Strict-Transport-Security` (not only when HTTPS / `X-Forwarded-Proto`) so security scans against direct :8080 still see the header; browsers ignore HSTS on cleartext.

## [0.0.7] - 2026-04-03
- Browser security headers: CSP (+ report-only mirror), COOP, CORP, Permissions-Policy, Referrer-Policy, X-Frame-Options; HSTS when the request is HTTPS or `X-Forwarded-Proto: https`.

## [0.0.6] - 2026-04-03
- Fix response hardening middleware: Starlette `MutableHeaders` has no `pop()` in some versions; remove `server` / `x-powered-by` by key iteration instead.

## [0.0.5] - 2026-04-03
- Run uvicorn with `--no-server-header` and strip residual `Server` / `X-Powered-By` in middleware; set `X-Content-Type-Options: nosniff` when absent.

## [0.0.4] - 2026-04-03
- Remove HTML and inline-style comments from `index.html` and `error.html` so served pages do not expose deployment hints in markup.

## [0.0.3] - 2026-04-02
- Align globe with globe-landing: static `config/defaults.json` (tone, calibration, stars), matching `STATIC_GLOBE_DEFAULTS` fallback in `js/globe.js`.
- Apply earth texture tone pass, lit `MeshStandardMaterial`, view yaw + rotation speed, and starfield density/brightness matching globe-landing’s formulas.
- Update stub `api/default/web/config.json` params to the same values.

## [0.0.2] - 2026-04-02
- Ship `default-site/assets/earth-equirect.jpg` in the image so the globe texture works when no assets volume is mounted.

## [0.0.1] - 2026-04-02
- New `default-html` image: serves a default landing page and a starfield-based `error.html`.

