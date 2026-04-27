---
task_id: 2026-04-27-sprint-as-cycle-s01-t04
sprint: 1
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-1
---

# Task 2026-04-27-sprint-as-cycle-s01-t04 — Implement `lib/sensors/legacy-parts-zero-residual.sh` and register it in `lib/sensors/manifest.yaml` (or equivalent registration surface) so the sensor catalog exposes it.

## Story

The migration sprints (2 and 4) move legacy `<slug>-part-N.md` and per-task `<slug>-s<NN>-t<MM>.md` files into the new sprint shape. Without a sensor that asserts zero residue post-migration, regressions can silently re-introduce the old shape (e.g., a future `/yoke:tech-spec` revert, a manual `git mv` mistake). This sensor pins the invariant and the Validator runs it at every cycle's verify step. Authoring it in sprint 1 means sprints 2, 4, and every future cycle can rely on it; the sensor itself is dormant until invoked.

## Technical implementation

- Create `lib/sensors/legacy-parts-zero-residual.sh` next to existing sensors (`lib/sensors/no-vibeflow-refs.sh` is the closest peer in shape).
- Shape:
  - Shebang: `#!/usr/bin/env bash`. `set -euo pipefail`.
  - No arguments. Operates on the working tree from the repo root.
  - Two parallel checks:
    1. Find any `.yoke/specs/*-part-[0-9]*.md` matches → if non-zero, emit one structured violation per match with `criterion: legacy-parts-zero-residual`, `status: fail`, `location: <path>`, `fix_instruction: "rename via git mv to .yoke/sprints/<slug>-s<NN>.md per the sprint-as-cycle PRD migration script"`, `sensor: legacy-parts-zero-residual`, `evidence: legacy -part-N spec file present`.
    2. Find any `.yoke/tasks/*-s[0-9]*-t[0-9]*.md` matches → if non-zero, emit one structured violation per match with `fix_instruction: "concatenate into .yoke/sprints/<slug>-s<NN>.md per migration"` and equivalent fields.
  - Output format: emit one JSON object per violation to stdout (newline-delimited), matching the structured-sensor-output convention in `concepts/yoke-pattern-sensors`.
  - Exit 0 if zero violations; exit 1 if any violation found.
- Register the sensor in `lib/sensors/manifest.yaml` (or the equivalent registration file). The registration block includes `id: legacy-parts-zero-residual`, `cost_tier: low` (file globs only, no LLM), `applies_to: [working-memory]`, `path: lib/sensors/legacy-parts-zero-residual.sh`. If the manifest does not exist as a single file, register via the `lib/sensors/` discovery mechanism per `concepts/yoke-pattern-sensors`.
- Add a self-test fixture under `tests/sensors/legacy-parts-zero-residual.test.sh` that creates a tmp working tree, populates one fake `-part-N.md` and one fake `-s<NN>-t<MM>.md`, invokes the sensor, asserts both violations are emitted, then removes the fakes and asserts a clean run. Cite `concepts/yoke-pattern-sensors`'s "Structured sensor output" rule.

## Validation

- Functional smoke: with the working tree carrying 62 `-part-N.md` files and 16 `-s<NN>-t<MM>.md` files, the sensor emits 78 violations and exits 1.
- Clean-tree smoke: against a hypothetical post-migration tree (no `-part-N` and no `-s<NN>-t<MM>`), the sensor exits 0 with empty stdout.
- Self-test: `bash tests/sensors/legacy-parts-zero-residual.test.sh` exits 0.
- Catalog smoke: `/yoke:ack-sensors` (catalog mode, if available; otherwise inspect `lib/sensors/manifest.yaml`) lists `legacy-parts-zero-residual`.
- Structured-output smoke: each emitted JSON object contains exactly the keys `criterion`, `status`, `location`, `fix_instruction`, `sensor`, `evidence` per `concepts/yoke-pattern-sensors`.

## Acceptance criterion

`bash tests/sensors/legacy-parts-zero-residual.test.sh` exits 0, AND `bash lib/sensors/legacy-parts-zero-residual.sh` against the current working tree (which contains the legacy files) emits ≥ 78 newline-delimited JSON violation objects on stdout and exits 1.
