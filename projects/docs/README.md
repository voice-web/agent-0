# agent-0 — docs hub

Single place under **`projects/docs/`** for notes, runbooks, and references. Add Markdown (or other) files here and **keep the index table below in sync** so you can ask for a list without hunting the tree.

---

## For assistants (how to “execute” this README)

When the user asks you to **follow this README**, **execute `projects/docs/README.md`**, or similar:

1. **Read this file** (`projects/docs/README.md`).
2. If they ask **what docs exist**, **list my docs**, **inventory the docs folder**, or equivalent — answer using **§ Doc index** below as the canonical list. If the table is empty or looks stale, also scan **`projects/docs/`** (see **§ Refresh rule**) and report any `.md` files not listed; suggest updating the table.
3. When **adding** or **renaming** a doc in this folder, **update the Doc index** in the same change when possible.

**Refresh rule:** Glob `projects/docs/**/*.md`, exclude this `README.md`, compare filenames to the index — call out orphans either way.

---

## Doc index

Add a row for every doc you care about tracking. Paths are relative to **`projects/docs/`**.

| Title | File | Summary |
|-------|------|---------|
| Cloud VM setup (Oracle first pass) | `oracle-vm-setup.md` | Cloud-agnostic baseline + Oracle: git, Docker CE, tool manager, OCI CLI, repos + symlinks, rollback |
| Deploy — VAP (Caddy + basic-http) | `deploy-vap.md` | First-pass deploy + undo flow; planned helper scripts for build/start/teardown |
| VAP platform — prototype pattern | `vap-platform-prototype.md` | Master meta-schema, **Schema** registry first, then domain entities; OpenAPI-only contracts, file store, faux broker |
| Entity schema contract (agent-0 standard) | `entity-schema-contract.md` | Vocabulary: **schema** = entity `*.schema.json`; **master schema** = contract for those files; link to abeja-reina reference CLI tree |
| Guiding principles — entity model & transforms | `guiding-principles-entity-model.md` | Entities as SoT, **transforms**, relationship/action entities (sketch), catch-all shapes for external specs, pragmatic code-first evolution |
| Nmap open ports (worldcliques.org) | `nmap-open-ports.md` | Captured Nmap output (2026-03-31) listing open TCP services + some NSE findings |

---

## Conventions (optional)

- **Flat or nested:** Subfolders are fine (e.g. `oci/notes.md`); list them in the table with full relative path from `projects/docs/`.
- **Naming:** Use readable names; the **Title** column can differ from the filename.
- **Cross-repo material** lives in other paths; link it from a doc *here* if you want it discoverable from this hub, or add a one-line pointer row with **Summary** = “ lives at `…` ”.

---

## Changelog (optional)

| Date | Change |
|------|--------|
| 2026-03-28 | Initial hub README + index. |
| 2026-03-29 | Added **`oracle-vm-setup.md`**, **`deploy-vap.md`**; indexed both. |
| 2026-03-30 | Expanded both docs with first-pass setup/undo steps and tomorrow planning checklist. |
| 2026-03-31 | VM doc: step 5 uses repos + symlinks instead of a fixed on-disk `sites/` layout. |
| 2026-03-31 | VM doc: accounts moved to step 2 (after SSH/update); steps renumbered. |
| 2026-03-31 | Added **`vap-platform-prototype.md`** (contracts, file store, faux broker); indexed. |
| 2026-03-31 | VAP prototype doc: **Schema** meta-entity + **master schema** first; Directory after registry. |
| 2026-04-02 | Converted `nmap-open-ports.txt` into `nmap-open-ports.md` and indexed. |
| 2026-04-04 | Added **`entity-schema-contract.md`** (entity vs master schema, reference path under abeja-reina); indexed. |
| 2026-04-04 | Added **`guiding-principles-entity-model.md`** (transforms, relationships, actions, catch-all shapes, incremental adoption); indexed; cross-linked from entity contract. |
