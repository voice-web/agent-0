# compose/ (legacy location)

Hand-maintained **`*.yml` files here were removed.** Operations use:

- **Sources:** `deployments/<id>/` (`deployment.json`, `routing.json`, `services.json`, `config.json`)
- **Compile:** `python3 scripts/compile.py <id>`
- **Generated compose + Caddyfile:** `.generated/<id>/edge/docker-compose.yml`, `.generated/<id>/app/docker-compose.yml` (not committed)
- **Bring up:** `scripts/up.sh`, `scripts/down.sh`, `scripts/update.sh`

See `DEPLOY_LOCAL.md` and `DEPLOYMENT_MODEL.md`.
