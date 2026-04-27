# Spec: Bedrock canonical-memory port — Part 2: `/yoke:memory` skill + bootstrap migration

> Generated via /vibeflow:gen-spec on 2026-04-25
> Source PRD: `.vibeflow/prds/bedrock-canonical-memory-port.md`

## Objective

Expose the registry through `/yoke:memory` and refactor `/yoke:bootstrap`
to use it — including a one-shot, transparent migration for existing
`.yoke/config.yaml` installs that still rely on the
clone-each-time cache.

## Context

Part 1 built the registry and resolution lib but wired no skills.
Users today have either no canonical memory configured, or a populated
`.yoke/config.yaml` `canonical_memory.url` plus a clone in
`~/.cache/yoke/canonical/<slug>/`. Bootstrap must transparently migrate
the second case to the new registry, and `/yoke:memory` must let users
manage memories from any project directory.

## Definition of Done

1. `skills/memory/SKILL.md` exists. `/yoke:memory` accepts subcommands:
   `list`, `add <path> [--url <git-url>] [--name <name>]`,
   `set-default <name>`, `remove <name>`. Each operation calls Part 1's
   registry library.
2. `/yoke:memory add <path>`:
   - existing path with a git repo → registers as-is.
   - non-existent or empty path → invokes Part 1's
     `lib/canonical-memory/scaffold-memory.sh` to scaffold a fresh
     repo, then registers it.
   - duplicate URL or name → rejects with a clear message pointing at
     the existing entry.
3. `skills/bootstrap/SKILL.md` is refactored: when
   `.yoke/config.yaml` has `canonical_memory.url` populated and the
   registry does not yet contain that URL, bootstrap clones to
   `~/.local/share/yoke/canonical/<derived-slug>/` (XDG default for
   migrated installs) and registers it.
4. After successful registration, bootstrap deletes the legacy
   `~/.cache/yoke/canonical/<slug>/` directory if present. Order is
   strictly `register → verify → delete cache`; cache deletion is the
   last step.
5. `.yoke/config.yaml` post-bootstrap carries both `canonical_memory.url`
   (unchanged, project-level pointer) and a new `canonical_memory.name`
   field linking to the registry entry.
   `templates/yoke-config.yaml` is updated to document the new field.
6. **Quality gate:** smoke test
   `tests/smoke/memory-migration.test.sh` covers (a) fresh install
   with no prior canonical memory, (b) install with existing
   `canonical_memory.url` pointing at a clone in
   `~/.cache/yoke/canonical/`, (c) `/yoke:memory add` for an empty
   directory (scaffolds), and (d) `/yoke:memory add` for an
   already-registered URL (rejects). All four scenarios succeed
   without manual intervention. Test wraps with `timeout 600` per
   pre-Sprint-6 conventions; bash 4+ assumed.

## Scope

- `skills/memory/SKILL.md` covering all four subcommands.
- `skills/bootstrap/SKILL.md` refactor — registry resolution +
  migration path.
- Migration logic: detect, register, drop cache.
- Smoke test for migration paths.
- `templates/yoke-config.yaml` update with `canonical_memory.name`.
- `docs/canonical-memory-setup.md` updated with `/yoke:memory`
  recovery instructions for plugin-reinstall (R-1.1 from Part 1).

## Anti-scope

- No `/yoke:ask`, `/yoke:preserve`, `/yoke:teach`, `/yoke:compress`,
  `/yoke:status` work — they live in Parts 3–6.
- No deletion of `lib/canonical-memory/query.sh` — Part 3 owns that.
- No `gh repo create` for fresh canonical memories in v0; the user
  supplies a path or URL. Bootstrap may suggest `gh repo create` in
  messaging, but does not run it.
- No XDG default for `/yoke:memory add`. XDG is *only* the fallback
  for the migration path; explicit `add` requires `<path>`.

## Technical Decisions

- **Migration is automatic and idempotent.** Bootstrap runs the check
  on every invocation; a no-op once the registry already contains the
  URL. No `--migrate` flag.
- **XDG (`~/.local/share/yoke/canonical/<slug>/`) for migrated
  installs only.** Avoids picking a default for new users while still
  giving migrated users a sensible auto-location.
- **`canonical_memory.name` is derived from the URL slug** when
  bootstrap migrates (basename minus `.git`). When the user runs
  `/yoke:memory add` with `--name`, the explicit name wins.
- **Registry rejects duplicate URLs** with a message naming the
  existing entry. Avoids two registry rows pointing at the same
  substrate.

## Applicable Patterns

- `.vibeflow/patterns/plugin-structure.md` — bootstrap remains the
  only Phase-0 entry point; this part keeps that invariant while
  shifting where the canonical memory ends up on disk.
- `.vibeflow/patterns/memory-model.md` — the two-tier model is
  preserved. The change is access mechanics
  (clone-each-time → registered local checkout); the lifetimes and
  authorities are unchanged.

## Risks

- **R-2.1 — Migration fails midway.** Cache deleted but registry write
  rejected → user loses the local checkout. *Mitigation:* the strict
  order in DoD-4 is `register → verify (test -d on registered path) →
  delete cache`; the last step never runs unless the first two
  succeed. Smoke test asserts the order.
- **R-2.2 — Two registry entries for the same URL.** *Mitigation:*
  registry lib (Part 1) rejects on duplicate URL or duplicate name;
  this part exercises both via DoD-2 and DoD-6.
- **R-2.3 — Bootstrap re-runs against an already-migrated install
  break the registry.** *Mitigation:* idempotency check — bootstrap
  reads the registry first; if a row already maps the URL → registered
  path, skip migration entirely.

## Dependencies

- `.vibeflow/specs/bedrock-canonical-memory-port-part-1.md`
