# Plan: deploy-docker → entity-schema model (sources first)

**Goal:** Treat **authoritative deployment inputs** as **entities** (entity-schema convention in [`entity-schema-contract.md`](entity-schema-contract.md)), keep **compile** as the **transform** to `.generated/`, and converge with [`guiding-principles-entity-model.md`](guiding-principles-entity-model.md).

**Scope for now:** Only the **source JSON** we already treat as truth under each bundle — not OpenAPI, not new microservices, not K8s output yet.

---

## 1. Sources we care about (unchanged filenames, for now)

Per bundle under **`deployments/<id>/`**:

| File | Role today | Entity type name (proposed) |
|------|------------|-----------------------------|
| **`deployment.json`** | Pointers: `deployment_id`, which files to load (`routing`, `services`, `config`) | **`deployment-bundle`** (index / envelope) |
| **`routing.json`** | Routing IR → Caddy (later other edges) | **`deployment-routing`** |
| **`services.json`** | Logical services manifest → compose | **`deployment-services`** |
| **`config.json`** | Environment overlay, flags, non-secret refs | **`deployment-config`** |

**Out of scope for this plan:** `scripts/compile.py` internals, Mustache templates, `.generated/` layout, `up.sh` — they stay as today until a later phase; we only **wrap validation and vocabulary** around the four sources.

---

## 2. Target end state (conceptual)

- Each file above is an **instance** of an **entity type** described by a **`*.schema.json`** next to a **`master.schema.json`** (same family as the abeja-reina POC, possibly a **second master** under deploy-docker: “deployment entity contract v1”).
- **`compile.py`** (or a thin prelude) **validates** instances against those entity schemas **before** merge/emit — same rules you’d use for a future CRUD API.
- **`schemas/*.schema.json` (JSON Schema)** today: either **replaced long-term** by transforms **entity-schema → JSON Schema**, or kept temporarily as a **second validation** until one pipeline wins (pragmatic: **overlap** briefly).

---

## 3. Phased plan

### Phase A — Inventory and naming (no behavior change)

- [ ] Document in **`DEPLOYMENT_MODEL.md`** (short subsection): these four files are **deployment domain entities**; **`compile`** is the **transform** from that bundle to edge + app compose + `resolved.json`.
- [ ] Optionally add a **README fragment** under `deployments/` pointing to this plan.

**Exit:** Everyone uses the same names (`deployment-bundle`, `deployment-routing`, …) when discussing migrations.

---

### Phase B — Entity schema files (parallel to JSON Schema)

- [ ] Add a directory, e.g. **`projects/deploy-docker/entity-schemas/`** (or `deployments/_entity_contracts/`), containing:
  - **`master.schema.json`** — `managedSchemaContractVersion: 1`, required/optional keys aligned with [`entity-schema-contract.md`](entity-schema-contract.md) (same **shape** as abeja-reina master; extend `optionalTopLevelKeys` only if we add deployment-specific metadata later).
  - **`deployment-bundle.schema.json`**, **`deployment-routing.schema.json`**, **`deployment-services.schema.json`**, **`deployment-config.schema.json`**.
- [ ] For **each** type:
  - **`name`**, **`schemaVersion`**, **`primary_key`** (e.g. bundle: `deployment_id` path or synthetic `name`; routing/services/config: **`deployment_id`** or bundle-relative id — pick one rule and document it).
  - **`fields`:** minimal **flat paths** needed for **tooling** (compile, linters, future UI) — can start **sparse** and grow.
  - **`shape`:** use the **catch-all** approach from the guiding principles for types that mirror large external-shaped JSON (**permissive `shape`** or envelope + `document`) so we **don’t** duplicate the whole JSON Schema tree in `fields` on day one. Tighten **`fields`** over time for paths **compile** actually reads.

**Exit:** Four entity schemas exist; humans can review them in PRs like any other contract.

---

### Phase C — Validate bundles against entity schemas in CI / compile

- [ ] Small Python module (stdlib-only if possible): **load master + type schema**, load **`deployment.json`** / **`routing.json`** / …, **validate** structure per `schema_contract.py`-style rules (reuse or vendor the abeja-reina **`validate_managed_entity`** pattern to avoid drift).
- [ ] Wire **`compile.py`** (start of `main`) or **`up.sh`** prelude: **fail fast** if any of the four files for the requested bundle fail entity validation.
- [ ] Keep existing **JSON Schema** validation if it catches things entity validation doesn’t yet — **dual validation** until entity schemas are strict enough.

**Exit:** Broken bundles fail before compose generation; entity layer is real, not decorative.

---

### Phase D — `deployment-bundle` as relationship-style index (optional but aligned)

- [ ] Treat **`deployment.json`** explicitly as the **bundle entity** that **references** the other three (by filename today; by **entity id** or **content hash** later).
- [ ] When **relationship entities** are defined (guiding doc), map this to a **relationship** or **weak link** pattern: bundle **associates** routing + services + config for one **`deployment_id`**.

**Exit:** Clear story for “one deployment = one bundle entity + three payload entities.”

---

### Phase E — Retire or derive JSON Schema (later)

- [ ] Either: **transform** entity-schema → JSON Schema for `deployments/` payloads (for external tools), or **drop** duplicate `schemas/*.schema.json` once entity validation is strict superset.
- [ ] Document which validators run in CI.

**Exit:** Single conceptual source of truth; JSON Schema only if derived or still needed for IDE.

---

## 4. What we explicitly defer

- OpenAPI generation from these entities (unless a **catch-all OpenAPI entity** is stored as output of a future transform).
- CRUD microservices / Swagger UI (guiding doc future).
- Kubernetes / nginx **transforms** (second target beside Caddy/compose).
- Moving bundles out of git into a DB (relationship entities + DB DDL transform — later).

---

## 5. Success criteria (MVP for “sources incorporated”)

1. **Four** deployment source types have **entity `*.schema.json`** files under deploy-docker, validated by a **master** in the same family as abeja-reina.
2. **`compile` (or equivalent)** **refuses** to run when a bundle’s sources violate those contracts.
3. **DEPLOYMENT_MODEL** (or this plan) states that **compile** is the **transform** from those entities to **`.generated/`**, and that **`.generated/`** is never hand-edited.

---

## 6. Changelog

| Date | Note |
|------|------|
| 2026-04-04 | Initial plan: four source files, phases A–E, deferred work. |
