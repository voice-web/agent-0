# VAP platform — prototype pattern (contracts, file store, faux broker)

This doc captures the **intentional prototype** architecture: move fast with **files** and **generated contracts**, then replace pieces with **purpose-built services** and **real infra** when requirements harden.

## Principles

1. **Contracts are the foundation** — **JSON Schema** (entity shape) and **generated OpenAPI** (HTTP contract) define what exists. **No coloring outside the lines**: no ad-hoc REST shapes or undocumented fields; only what the specs say (plus **documented** `x-` extensions if you ever need them).
2. **Generic entity-CRUD first** — one runtime (or one deployment profile) implements CRUD **from** the OpenAPI + schemas instead of hand-writing a new service per entity for every experiment.
3. **Exit ramp** — when an entity needs real workflows, queries, SLAs, or isolation, **split** to a dedicated service while keeping **stable ids**, **versioned APIs**, and **events** where possible.

## Artifact pipeline (target)

| Step | Output | Role |
|------|--------|------|
| Define entity | JSON Schema (required fields, types, constraints) | Validation + documentation |
| Generate | OpenAPI (`operationId`, paths, models, **Keycloak-aligned scopes** in `security`) | HTTP contract for humans, CLIs, and the generic engine |
| (Optional) Generate | CLI / thin client | Same contract, no hand-written URLs |
| Run | **Entity-CRUD service** | Dispatches to a **storage adapter** using the spec |

**Storage (now):** files under a **convention-based directory layout** (e.g. per-`schemaId` paths). **Later:** swap the adapter for a DB, object store, etc., without changing the **contract** at the boundary.

## File-backed “message broker” (simulation)

To **play with workflows** before adopting **JetStream**, **Kafka**, or similar:

- **Publish events** — treat as **append-only**: e.g. `POST`/`PUT` that **creates a new event record** (new file or new line with a **monotonic id** / sequence). Avoid mutating history in place.
- **Consume** — be explicit:
  - **Peek** — read without advancing a consumer cursor (like browsing a log).
  - **Commit / ack** — separate operation or body that advances **offset** so redelivery matches **at-least-once** semantics you’ll see in real brokers.

A naive **`GET` that deletes** can stand in for “pop,” but document it as such so replacing it with **JetStream pull/consume** stays a **mechanical** change.

**Ordering:** define **partitioning** (e.g. per `entityId`, `tenantId`, or stream name) so you don’t accidentally assume **global** ordering.

## Auth

**Keycloak** tokens with **scopes** align with OpenAPI **`security`** on operations. Row-level rules still need **claims** (tenant, owner) or policy — scopes alone are coarse.

## First entity: **Schema** (meta / registry)

The **first** thing to model is not a domain object like Directory — it is the **meta entity** that **is** (or points at) **entity schemas**: call it **Schema**, **EntitySchema**, or **EntityDefinition** — same idea.

**Why first**

- Every other entity’s JSON Schema (and thus generated OpenAPI) must **conform to rules** you care about: required metadata (`id`, `version`, `title`, …), naming, extensibility (`x-vap-*`), validation hooks, etc.
- Implementing **CRUD for schema records** first gives you a **registry** in the file store (or future DB): `entity/schema/data/<uuid>.json` (or your convention) becomes **data governed by the platform**, not ad-hoc files.
- **Directory** (and everything else) comes **after**: each new domain entity is **just another schema document** that passes the **master** rules, then gets CRUD + events like any other type.

## Master schema (schema-for-schemas)

You need a **single authoritative JSON Schema** (the “master” or **meta-schema**) that defines **what a valid entity schema document looks like** when someone creates or updates a **Schema** instance.

- New entity types are **instances** of **Schema** whose **body** is (or embeds / references) a JSON Schema that **itself** validates against the **master**.
- The generic **entity-CRUD** service can use the **master** to validate **writes** to the Schema entity before accepting a new type into the registry.
- **OpenAPI** for the **Schema** entity is still generated under the same conventions as every other entity — **no special casing** in the contract layer; any special behavior lives in **validation** and **policy** (Keycloak scopes on schema admin vs read).

This **bootstrapping order** is intentional: **master schema → Schema CRUD → generate/register schemas for Directory and the rest** so the platform **forces** consistency instead of drifting file-by-file.

## What comes next

- Review **what’s already built** in repos (deploy, images, docs).
- Define the **master schema** and the **Schema** entity (JSON Schema + generated OpenAPI), wire **Schema** through the **generic CRUD** path.
- Register **downstream** entity schemas (e.g. Directory) **through** that mechanism.
- Then either keep iterating on the **prototype stack** or promote one boundary to a **purpose-built microservice**.
