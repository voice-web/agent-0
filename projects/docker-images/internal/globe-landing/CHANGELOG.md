# Changelog

## [0.0.5] - 2026-04-03
- Static server: `Cache-Control: no-cache` for `.html` / `.js` / `.css` / `.json` so rebuilt images are not masked by browser disk cache.
- `index.html`: cache-bust query on `globe.js` and `styles.css`; `console.info` logs script tag so DevTools proves the loaded bundle.

## [0.0.4] - 2026-04-03
- Resize: coalesce with `requestAnimationFrame`, size from `getBoundingClientRect()`, refresh `setPixelRatio`, immediate `renderFrame()` after `setSize`.
- Listen to `visualViewport` resize/scroll (mobile toolbar / vertical viewport changes).

## [0.0.3] - 2026-04-03
- Fix globe disappearing after window resize: `resize()` no longer returns early on transient 0×0 container metrics (use `Math.max(…, 1)` like default-html), and `window.resize` now calls `resize()` as well as star layers.

## [0.0.2] - 2026-04-03
- Replace `python -m http.server` with a small stdlib static server (`serve.py`): `Server: httpd` instead of Python stack banner; send `X-Content-Type-Options: nosniff`.
- Remove HTML comment from `index.html`.

## [0.0.1] - 2026-04-02
- Initial `globe-landing` internal image.
- Bakes in the VAP `projects/globe-landing/site` static content and serves it with `python3 -m http.server`.
- Includes `site/assets/earth-equirect.jpg` and adds `scripts/fetch-earth-texture.sh` to refresh texture.

