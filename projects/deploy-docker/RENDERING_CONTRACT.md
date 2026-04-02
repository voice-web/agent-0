# Rendering contract (what the renderer must do)

This document defines the expected output from the renderer so you can validate it without committing to a specific implementation language yet.

## Inputs

1. `manifests/*`: logical service manifest sets (e.g. `infra`, `services`, or `full`).
2. `configs/*`: per-environment overlay containing values for each logical service.
3. `routing/*` (optional but recommended): host/path routing rules (including WebSockets).
4. `images/*` (optional): lookup table mapping logical service `image.ref` to actual tags/digests.
5. `secrets/`: injected at runtime (never committed).

## Merge rules (deterministic)

- Start with manifest structure.
- Overlay config fills in:
  - env values
  - mount sources
  - feature flags
  - any optional runtime parameters
- Missing required keys should be a hard error during rendering.

## docker-compose output expectations

Your renderer should output:

1. `services:` entries for each logical service
2. a consistent user-defined network so containers can reverse-proxy by service name
3. `depends_on` or health-based ordering where needed (Caddy depends on backends)
4. healthchecks for anything that participates in routing

## Ingress output

You have two valid patterns:

### Pattern A: Caddy routing from a routing contract
- Render a Caddyfile based on `routing/*.json|yaml`

### Pattern B: Caddyfile is “manual input”
- Manifest selects container + config; operator edits the Caddyfile directly

Pattern A is better long-term because it keeps ingress changes auditable.

