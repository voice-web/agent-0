# Changelog

## [0.0.2] - 2026-04-03
- Replace `python -m http.server` with a small stdlib static server (`serve.py`): `Server: httpd` instead of Python stack banner; send `X-Content-Type-Options: nosniff`.
- Remove HTML comment from `index.html`.

## [0.0.1] - 2026-04-02
- Initial `globe-landing` internal image.
- Bakes in the VAP `projects/globe-landing/site` static content and serves it with `python3 -m http.server`.
- Includes `site/assets/earth-equirect.jpg` and adds `scripts/fetch-earth-texture.sh` to refresh texture.

