# default-html

Default HTML container for `worldcliques.org` (web host).

It serves:
- `/` => `index.html` (rotating globe + starfield)
- other non-asset paths => `error.html` (starfield background + centered white error box)
- `/health` => JSON (for compose healthchecks)

## Static files layout

The container serves from `/srv/www`.

### Baked-in
- `index.html`
- `error.html`

### Expected to be mounted (from `vap/projects/globe-landing/site`)
- `css/styles.css`
- `js/globe.js`
- `config/defaults.json`
- `api/default/web/config.json`
- `assets/*` (earth texture + icons)

Without these, you will still get an error box, but the globe/starfield may not render correctly.

## Compose mounting example

Mount the globe-landing site assets into matching paths under `/srv/www`.

Example (illustrative; adapt paths to your compose layout):
```yaml
  default-html:
    image: local/default-html:0.0.8
    volumes:
      - ./path/to/globe-landing/site/css:/srv/www/css:ro
      - ./path/to/globe-landing/site/js:/srv/www/js:ro
      - ./path/to/globe-landing/site/config:/srv/www/config:ro
      - ./path/to/globe-landing/site/api:/srv/www/api:ro
      - ./path/to/globe-landing/site/assets:/srv/www/assets:ro
```

## Caddy routing + default proxy errors (expected)

You typically configure Caddy so:
- `api.worldcliques.org` forwards to the API container (JSON errors)
- `worldcliques.org` and `*.worldcliques.org` forward to `default-html` (HTML errors)

For Caddy error handling, the simplest approach is:
- let upstream failures bubble up to Caddy
- configure `handle_errors` to reverse-proxy to `/error.html` for the HTML host

The `default-html` container already returns `error.html` for non-asset 404s and renders it for 500s, so Caddy doesn't need to do much beyond serving a reasonable response when the upstream is unreachable.

