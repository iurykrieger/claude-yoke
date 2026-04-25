---
name: status
description: >
  Reports the current task's phase, working-memory presence, and recent
  canonical-memory activity. Read-only — never modifies state. Placeholder
  in v0.1.0; full implementation lands in Sprint 8.
---

# /yoke:status — current task state (placeholder)

Not yet implemented in v0.1.0. Implementation lands in Sprint 8 per
`.vibeflow/specs/yoke-v1-sprint-8.md` (PRD Open Question 10 resolves the
exact reporting scope).

## Planned behavior

- Reports: current phase, presence and approval state of `.yoke/*.md`
  artifacts, last canonization PR, hard-bound consumption (Sprint 6+),
  Phase-6 last-run summary (Sprint 7+).
- Read-only — never modifies state.

See also: `.vibeflow/patterns/phase-flow.md`.
