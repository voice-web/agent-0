# Deployment Engineering Best Practices

This doc captures the best practices behind your workflow:
**logical-service manifest + per-environment config + renderer (Compose or Kubernetes)**.

## The core idea: separate concerns into layers
Model deployment as distinct layers with clear “source of truth”:

1. **Images**
   - What runs (built image names + versions/digests).
2. **Logical services**
   - What capabilities you want (e.g. `default-html`, `default-api-json`, `caddy`, `keycloak`).
3. **Ingress / routing**
   - How requests reach those logical services (hosts, paths, WebSockets behavior).
4. **Service config overlays**
   - Environment-specific parameters: env vars, mounts, feature flags, health endpoints.
5. **Secrets**
   - Credentials and TLS/ACME material injected at runtime; never committed.

The renderer combines the layers, but you keep them conceptually independent to avoid “moving parts in the wrong place”.

## Compose vs Kubernetes: parity without forcing sameness
Prefer a single logical model that can generate either output type:
- `docker-compose.yml` for local/compose environments
- Kubernetes YAML for K8s environments

Best practices for parity:
- Keep the *logical service interface* stable across platforms:
  - container port(s)
  - health endpoint(s)
  - required env vars
  - owned routes / protocols (HTML vs JSON, WebSockets if applicable)
- Let the renderer handle platform specifics:
  - **Compose**: service-name DNS on a user network, bind mounts/named volumes, healthchecks, ordering (`depends_on`)
  - **Kubernetes**: Services + Deployments, readiness/liveness probes, PVCs, namespaces, optional NetworkPolicy
- Make ingress generation explicit:
  - either render Caddy from a routing contract, or keep the ingress configuration as operator-managed input.

## External services: treat them as infrastructure
Your “external services” are typically stable primitives:
- **Caddy** (edge / ingress)
- **Keycloak** (identity / OIDC)
- (often) databases required by Keycloak

Guidelines:
- **Routing policy belongs in ingress** (Caddy/routing contract), not inside app containers.
- Persist Caddy state (ACME/TLS) with volumes.
- Configure identity with proxy-awareness:
  - ensure correct forwarded headers and issuer URLs
  - avoid redirect-uri surprises when hosted under subpaths/hosts
- Separate Keycloak clients by purpose:
  - browser login client (web flow)
  - service-to-service tokens (client_credentials)

## Internal services: keep them “dumb and predictable”
Internal containers like `default-html` and `default-api-json` should have a strict deploy-time interface:
- predictable behavior by route family:
  - HTML host: HTML-aware 404/500 fallback (default error page)
  - API host: JSON-only errors + CORS baseline for token auth
- avoid assuming hostnames/cookies inside containers
- WebSockets (if present) should have well-defined handshake/auth expectations

This makes containers reusable and keeps environment variance localized to configuration overlays.

## Configuration layering: defaults + overlays + per-service overrides
Prefer deterministic merging:
- shared defaults (common values)
- infra overlay (Caddy/Keycloak tuning)
- environment overlay (dev/stage/prod)
- per-service overrides (mounted volumes, env vars, feature flags)

Practical benefits:
- easier review (diffs show which layer changed)
- fewer accidental breaking changes when adding new services
- predictable renderer input shape

## Manifest + config + renderer: a proven workflow
Your approach:
1. **Manifest sets** choose what logical services to deploy.
   - e.g. `infra` set: `caddy`, `keycloak`
   - e.g. `services` set: `default-html`, `default-api-json`, etc.
2. **Configuration sets** provide the parameters for each logical service.
   - env vars, mount sources, healthcheck paths/ports, feature flags
3. **A deploy script/renderer** combines:
   - manifest(s)
   - config overlay(s)
   - (optional) routing contract
   - outputs a deploy artifact (Compose or K8s manifests)

Key best practice:
- keep route wiring/ingress generation as a separate input (routing contract),
  rather than “hardcoding it inside each logical service”.

## Recommended repository organization (conceptual)
- `manifests/`:
  - logical service sets (infra-only, services-only, full, etc.)
- `configs/`:
  - per-environment overlays
- `routing/`:
  - host/path routing rules (optionally includes WebSockets pass-through)
- `images/` (optional):
  - mapping from logical service `image.ref` to actual pinned tags/digests
- `secrets/`:
  - runtime-only injected inputs

## Success criteria (what “good” looks like)
- A new service only requires:
  1) a manifest entry (what it is),
  2) a config overlay (how it is configured),
  3) optionally a routing rule (how it is reached).
- Switching from Compose to Kubernetes does not require redesigning logical services.
- Error handling and CORS behavior are consistent per route family (HTML vs API).
- Ingress behavior (including WebSockets) is testable and documented.

