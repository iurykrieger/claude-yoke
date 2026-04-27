# Sprint 06 of 06: Bedrock canonical-memory port

> Migrated from: # Spec: Bedrock canonical-memory port — Part 6: `/yoke:compress` + `/yoke:status` extension


> Generated via /vibeflow:gen-spec on 2026-04-25
> Source PRD: `.vibeflow/prds/bedrock-canonical-memory-port.md`

## Objective

Ship `/yoke:compress` for canonical-memory alignment maintenance, and
extend the existing `/yoke:status` to absorb bedrock's healthcheck
surface — same skill, no separate `/yoke:healthcheck`.

## Context

Canonical memory drifts: backlinks rot, entities fragment, names
diverge, content gets stale. Bedrock has `/compress` (active fixes) and
`/healthcheck` (read-only diagnostic) for these. Per PRD resolution,
healthcheck is folded into Yoke's existing `/yoke:status` (the two are
the same skill). Compress proposes fixes through `/yoke:preserve`
(Part 4), so the single-write-point invariant holds.

## Definition of Done

1. `skills/compress/SKILL.md` ships, copied from bedrock 1.2.1 with
   namespace renames; supports `--mode cron` for scheduled execution
   and `--dry-run` for preview-only runs.
2. `/yoke:compress` detects and proposes fixes for the 5 misalignment
   classes from bedrock: broken backlinks, concept fragmentation,
   entity miscategorization, duplicated entities, misnamed entities.
   All proposed fixes go through `/yoke:preserve` (Part 4) — compress
   never writes directly.
3. `skills/status/SKILL.md` is extended to report bedrock's
   healthcheck surface for the active memory: graphify-out integrity
   (or "n/a — graphify not configured"), orphan entities, dangling
   content, content older than 15 days. Existing `/yoke:status`
   working-memory reporting (current task slug, phase, hard-bound
   counters) stays.
4. `lib/canonical-memory/staleness-check.sh` is folded into
   `/yoke:status`'s healthcheck section and removed as a standalone
   library file. Its rippability validation logic
   (`last_validated` vs `model_calibrated_against`) becomes part of
   `/yoke:status --canonical`.
5. `--mode cron` defaults to `--dry-run` unless `--apply` is also
   passed. Cron mode emits a structured report to stdout; with
   `--apply`, fixes go through `/yoke:preserve`'s normal Model C
   routing (typically `low` impact for alignment fixes).
6. **Quality gate:** `/yoke:status` is read-only — verifiable by smoke
   test running 100 consecutive `/yoke:status` calls and asserting
   zero git commits, zero entity edits, zero
   `lib/canonical-memory/*.sh` writes against the active memory.
   Wraps with `timeout 600` per pre-Sprint-6 conventions.

## Scope

- `skills/compress/SKILL.md` (new, copied from bedrock 1.2.1).
- `skills/status/SKILL.md` extension (healthcheck surface).
- Removal of `lib/canonical-memory/staleness-check.sh`.
- Smoke test: `/yoke:status` is read-only.

## Anti-scope

- No standalone `/yoke:healthcheck` skill (per PRD).
- No automatic compression schedule wiring — `--mode cron` is
  *supported*, not *configured*. Users wire it via `/loop`,
  `/schedule`, or external cron.
- No graphify integration in compress's analysis (deferred sprint).
- No new misalignment classes beyond bedrock's 5.

## Technical Decisions

- **Compress proposes through `/yoke:preserve`.** Compression is a
  write; the single-write-point invariant from Part 4 says all writes
  go through preserve. This means compress's user prompt → preserve's
  Phase 3 confirmation gate → Model C routing. Typically `low`
  impact. No direct `git -C <memory>` calls from compress.
- **Status is unified, not split.** Per PRD Open Question resolution,
  healthcheck = status. The skill takes optional flags
  (`--working-memory`, `--canonical`, `--all`, default `--all`) to
  scope output. The existing `/yoke:status` working-memory output is
  preserved; canonical-memory output is added.
- **Cron-mode safety default.** `--mode cron` without `--apply` is a
  read-only report. Users explicitly opt into apply-on-cron. Avoids
  R-6.1 (PR flood from unattended runs).
- **`staleness-check.sh` logic moves into `/yoke:status --canonical`.**
  Rippability validation is a healthcheck concern, not a write
  concern. Keeping it as a library is dead weight after the move.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — compress writes go through
  preserve; status is read-only. Both invariants reinforced.
- `.vibeflow/patterns/model-c-governance.md` — compress fixes are
  classified by preserve's Phase 3 (typically `low`); no special
  governance path.

## Risks

- **R-6.1 — Cron-mode PR flood.** `--mode cron --apply` running
  unattended could produce many low-impact PRs. *Mitigation:*
  cron-mode safety default (DoD-5: dry-run unless `--apply`); document
  in `docs/canonical-memory-setup.md`.
- **R-6.2 — Compress vs human edits.** A human edits an entity
  manually; compress sees it as misnamed and proposes a "fix"
  reverting the edit. *Mitigation:* bedrock's existing "merge, never
  delete" rules cover this — compress's proposal would either be a
  no-op or get rejected by preserve's Phase 3 confirmation.
- **R-6.3 — Status output bloat.** Adding healthcheck surface to
  `/yoke:status --all` could make output unreadable. *Mitigation:*
  scoped flags (`--working-memory`, `--canonical`, `--all`) let users
  pick; default `--all` collapses sections that pass with a single
  "OK" line.

## Dependencies

- `.vibeflow/specs/bedrock-canonical-memory-port-part-1.md`
- `.vibeflow/specs/bedrock-canonical-memory-port-part-4.md`
