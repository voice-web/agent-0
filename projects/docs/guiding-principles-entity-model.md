# Guiding principles — entity model, transforms, and evolution

**Status:** Living document — iterate as we learn. These are **principles to steer toward**, not a mandate that every line of code must satisfy on day one.

**Related:** Vocabulary and reference POC for `*.schema.json` files: [`entity-schema-contract.md`](entity-schema-contract.md).

---

## 1. Everything is an entity

- The **source of truth** for a kind of thing is its **entity schema** (and instances that conform to it).
- **Deployment intent**, **edge/routing intent**, **OpenAPI blobs**, **transform definitions**, etc. can all be modeled as **entities** over time — not only “business” rows like users or tenants.

---

## 2. Derive programmatically; don’t treat outputs as sources of truth

- **Outputs** (OpenAPI YAML, Caddyfile, `docker-compose.yml`, K8s manifests, generated clients) should come from **entities** via **automated steps**, not from hand-edited canonical copies.
- **Pragmatic start:** we may still **commit** generated artifacts for visibility or CI; long term, prefer **reproducible transforms** (same entities → same output) or **don’t commit** outputs.

---

## 3. Transforms (not “generators”)

- A **transform** takes **entity data** (and optionally parameters) as **input** and produces **output** — files and/or **other entities**.
- Examples: entity schema → OpenAPI document entity; routing intent → Caddyfile; same intent → nginx config; logical deployment graph → Compose or Kubernetes.
- A **transform** can itself be described as an **entity** (metadata: inputs, outputs, version, implementation reference), so orchestration stays **data-first** even though **implementations** remain code (or plugins) somewhere.

---

## 4. Relationship entities (the “R” in ER)

- A **relationship entity** **links** a set of **entity references** (the participants) and carries **attributes of the association** (cardinality, role names, effective dates, ordering, etc.).
- Use this to model graphs (who relates to whom) without overloading a single “wide” entity.
- **Direction:** entity schemas remain the contract for **structure**; relationship entities add **graph semantics**. Later, use the same schemas to **derive** persistence (e.g. tables + join tables) when moving from **file-backed** storage to a **database** — the model should not depend on files forever.

---

## 5. Action entities (sketch)

- An **action** entity describes **what to do** in a context (verb + target + parameters), possibly **independent** of how it is executed.
- **Transforms** may **consume** action entities (e.g. “emit this OpenAPI”, “apply this deployment”) — details **not fully worked out** yet.
- Principle: keep **intent** in **data** where it pays off; **executors** stay pluggable.

---

## 6. Catch-all shapes for “world standard” payloads

- We **don’t** always know or want to fully specify every nested field up front (e.g. a full **OpenAPI** document).
- **Rule of thumb:**
  - **Things we define and own** → prefer **explicit** `fields` / **concrete `shape`** so tools and UIs can be strict.
  - **Standard external artifacts** (OpenAPI, JSON Schema drafts, vendor configs) → allow an entity type whose **shape** is **permissive** (e.g. “document” / arbitrary JSON object, or minimal envelope + `payload`) so we **register and version** the artifact **without** mirroring the whole spec in our schema.
- That avoids painting ourselves into a corner while still keeping **one entity convention** for **identity**, **metadata**, and **provenance**.

---

## 7. How we work in the meantime (slow, practical)

- **Mindset:** When solving a problem, ask whether it should be a **named entity**, whether **outputs should be derived**, and whether we are encoding **intent** vs **implementation**.
- **Reality:** We may **not** define **action** or **transform** entities immediately — we **write code** (`compile.py`, one-off scripts, CLIs) to **move fast**.
- **Later:** Review what we built, **extract** recurring patterns into **named transforms** and **actions**, and align **deployment JSON Schema** and other artifacts with the **entity-first** model **without** big-bang rewrites.
- This doc is the **lens** for those reviews — **steer** toward the model; **allow** incremental adoption.

---

## 8. Session handoff

For assistants: read this file plus [`entity-schema-contract.md`](entity-schema-contract.md) when the user asks for **entity / schema / transform / deployment unification** work in **agent-0**.

**Changelog (high level)**

| Date | Note |
|------|------|
| 2026-04-04 | Initial capture: entities, transforms, relationships, actions (TBD), catch-all shapes, pragmatic evolution. |
