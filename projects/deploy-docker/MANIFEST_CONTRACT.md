# Manifest contract

This is the **input model** for your renderer.
The manifest describes **logical services** and their *deploy-time* interface requirements.
It does **not** define how URLs are routed (that’s the routing contract).

## Conceptual types

- `LogicalService`
  - `name`: stable identifier used in config and routing
  - `image`: how to pick the container image (either embedded string or via lookup)
  - `runtime`: what the container needs to run (ports, env, mounts, healthcheck)
  - `capabilities`: what kinds of protocols/behaviors it expects (static HTML vs JSON, websockets, etc.)
  - `owned_routes` (optional): only used for human documentation; routing is not generated from here

## Suggested JSON shape (v1)

```json
{
  "schema_version": "1.0",
  "set_name": "infra" ,
  "logical_services": [
    {
      "name": "caddy",
      "image": { "ref": "local/caddy:2.8.4" },
      "runtime": {
        "ports": [ { "container": 80, "published": 80 } ],
        "env": { "KEY": "VALUE" },
        "mounts": [ { "type": "bind|volume", "src": "./Caddyfile", "dst": "/etc/caddy/Caddyfile", "mode": "ro" } ],
        "healthcheck": { "path": "/health", "port": 80 }
      },
      "capabilities": {
        "kind": "ingress",
        "websocket": "maybe|required|not_applicable"
      }
    }
  ]
}
```

## Environment config overlay (separate file)

The renderer merges:
- manifest (structure + required env keys)
- config overlay (values + mount sources)

So the manifest should keep structure stable and allow config overlays to vary frequently.

