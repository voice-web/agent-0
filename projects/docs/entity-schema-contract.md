# Entity schema contract (guiding principles)

This document standardizes vocabulary and patterns when we talk about **schemas** in **agent-0** work. It summarizes a reference implementation that lives under **abeja-reina** (Cursor `.ray` project output).

## Vocabulary

| Term | Meaning |
|------|--------|
| **Schema** (entity schema) | The **contract for one kind of entity**: a managed JSON document (`*.schema.json`) describing **name**, **schemaVersion**, **primary_key**, **fields** (flat path strings), and optionally **shape** (example document). |
| **Master schema** | **Not** an entity. The **meta-contract** that every entity `*.schema.json` must satisfy: allowed top-level keys, version of that contract, and rules enforced when creating or editing entity schemas. |
| **Shape / sample** | Optional embedded **example JSON** (or `{ "example": … }` wrapper). Used to **derive** `fields` when lists are built by flattening nested objects (dotted paths, `[0]` for “first element of list of objects”). |

## Reference implementation (abeja-reina)

Canonical example tree (stdlib-oriented tooling: `schema-cli`, `schema_contract.py`, `schema_shape_utils.py`, domain CLIs):

- **Absolute path (this machine):**  
  `/Users/ray.jimenez/voice-web/git/abeja-reina/.ray/project/d526fbc1-c32c-4778-b590-4dfa17a177b9/outputs`
- **Typical sibling layout from agent-0:**  
  `../abeja-reina/.ray/project/d526fbc1-c32c-4778-b590-4dfa17a177b9/outputs`

Notable files there:

| Path (under `outputs/`) | Role |
|-------------------------|------|
| `schemas/master.schema.json` | Master contract document (`managedSchemaContractVersion`, required/optional top-level keys). |
| `schemas/*.schema.json` | Entity schemas (e.g. `crts-user`, `crts-transform`, `crts-tenant`). |
| `schema_contract.py` | Validates entity documents against the master contract (Python; keep in sync with `master.schema.json`). |
| `schema_shape_utils.py` | Flatten nested JSON examples → field paths for CLIs. |
| `schema-cli` | **Generic** lifecycle for **schema definition files** (create, validate, delete, create/update-from-sample). |
| `cli_template_base.py` | Minimal REPL template **without** schema loading. |
| `crts-user-cli`, `transform-cli` | **Domain** CLIs: load one entity schema + shared utils, implement storage and commands. |

## Principles when building or discussing tools

1. **Schema = entity contract.** Prefer the word **schema** for `*.schema.json` entity definitions, not for unrelated JSON Schema files unless the context is explicit (e.g. deploy-docker’s `schemas/` folder is **deployment input** JSON Schema — different domain).
2. **Master schema defines the shape of schema files.** Entity schemas are validated against it so tooling stays consistent.
3. **Generic vs domain CLIs.**  
   - **Generic:** manage **schema definitions** (and shared shape utilities) for **any** entity that follows the master contract.  
   - **Domain:** load **one** (or a fixed set of) entity schema(s) and implement **business behavior** (CRUD, transforms, etc.).
4. **Fields are flat paths** aligned with how records are edited in simple stores (CSV/JSON rows keyed by path strings). **Primary key** must be representable in that field list (including composite keys as multiple field paths).
5. **Optional `shape`** documents the intended nested JSON; **fields** can be explicit or derived from `shape` when `fields` is empty (see reference `schema-cli` / `resolve_schema_fields` behavior).

## Broader platform principles

For **transforms**, **relationship entities**, **action entities**, **catch-all shapes** for external standards, and **how we evolve incrementally** (code first, extract patterns later), see **[`guiding-principles-entity-model.md`](guiding-principles-entity-model.md)**.

## Session handoff

When starting a **new** chat about this topic, read **`projects/docs/entity-schema-contract.md`** and **`projects/docs/guiding-principles-entity-model.md`**, and point at the abeja-reina path above if the workspace does not include that tree.
