# globe-landing

Internal image that serves the VAP globe-landing static site with:

`python3 -m http.server <PORT>`

## Port

- Container port: `8080` (override with env `PORT`)

## Build

From `projects/docker-images`:

```bash
# Optional refresh:
./internal/globe-landing/scripts/fetch-earth-texture.sh

./scripts/build-local.sh internal/globe-landing
```

## Run

```bash
docker run --rm -p 8080:8080 local/globe-landing:0.0.2
```

Open:

- `http://127.0.0.1:8080/`
- `http://127.0.0.1:8080/?mode=interactive`
- `http://127.0.0.1:8080/?controls=1`

## Notes

- This image includes the static `site/` content from VAP `projects/globe-landing/site`.
- `site/assets/earth-equirect.jpg` is bundled so the globe texture works by default.
- To refresh/update the texture, run `./internal/globe-landing/scripts/fetch-earth-texture.sh` before build.
- If icon files are absent, favicon requests may fail gracefully.

