# compose/ — local bring-up examples

These compose files support the reference bring-up workflow:
- `up.sh infra 127.0.0.1` starts `caddy` + `keycloak` and creates a shared docker network.
- `up.sh application 127.0.0.1` starts `default-html` + `default-api-json` on the same network.

Request routing for local:
- `http://127.0.0.1/api/*` -> `default-api-json`
- `http://127.0.0.1/auth/*` -> `keycloak`
- everything else -> `default-html`

Keycloak admin credentials:
- The infra compose file reads Keycloak admin username/password from `env_file`
- The default path is `~/.secrets/worldcliques/127.0.0.1/keycloak.env`

