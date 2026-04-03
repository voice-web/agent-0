# Examples (reference)

Concrete inputs now live as **deployment bundles** under **`deployments/`**, for example:

- **`deployments/local-path-127/`** — path-based routing on `:80` (`127.0.0.1`, `/api`, `/auth`, `/ui`, default HTML)
- **`deployments/vm-host-oci/`** — host-based routing (`api` / `auth` / HTML vhosts, `:80` + `:443`)

Each bundle contains **`deployment.json`**, **`routing.json`**, **`services.json`**, and **`config.json`**. After **`python3 scripts/compile.py <id>`**, inspect **`.generated/<id>/resolved.json`** and the emitted **`Caddyfile`** / compose files.

See **`DEPLOYMENT_MODEL.md`** for the design contract and **`DEPLOY_LOCAL.md`** for how to run stacks.
