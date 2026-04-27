---
task_id: 2026-04-27-sprint-as-cycle-s03-t07
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
---

# Task 2026-04-27-sprint-as-cycle-s03-t07 — Update `.yoke/runtime/progress.md` template (and any seed in `lib/working-memory/`) to add `current_sprint:` and `completed_sprints:` frontmatter, and reset the `cycle_log:` array at sprint boundaries; `progress.md` stays a single file.

## Story

`progress.md` is the runtime's append-only log of cycles. Under the new shape it gains two frontmatter fields: `current_sprint:` (zero-padded 2-digit pointer to the active sprint) and `completed_sprints:` (array of completed sprint IDs). The cycle log resets at sprint boundaries — when a sprint converges, the log is archived (or a section break is inserted) and `cycle_count:` resets to 0. The file stays a single file (PRD anti-scope: no per-sprint progress files); the structure inside the file evolves.

## Technical implementation

- Locate the `progress.md` template / seed. Likely candidates: `templates/progress.md` or a heredoc inside `lib/working-memory/init-runtime.sh` or `skills/bootstrap/SKILL.md`.
- Define the new frontmatter shape:
  ```yaml
  ---
  slug: <slug>
  current_sprint: 01            # zero-padded 2-digit pointer
  completed_sprints: []          # array of zero-padded sprint IDs
  cycle_count: 0                 # cycles since the active sprint started
  total_sprints: <N>             # populated from spec at run start
  ---
  ```
- Body shape:
  - One H2 section per sprint: `## Sprint <NN>` containing the cycle log entries for that sprint.
  - Inside each sprint section, one H3 per cycle: `### Cycle <C>` containing the cycle's free-form notes.
  - A new sprint H2 is inserted whenever `current_sprint:` advances; the previous sprint's section is implicitly archived (no truncation, just demarcation).
- Update `skills/bootstrap/SKILL.md` if it bootstraps `progress.md` to seed the new frontmatter shape on first creation.
- Update `lib/ralph-loop/orchestrate.sh` (which already gets the cycle-counter changes in t03) to read/write the new fields.
- Add a one-shot migration step: if an existing `progress.md` lacks `current_sprint:` (e.g., from a previous run on the OLD shape), inject `current_sprint: 01`, `completed_sprints: []`, `cycle_count: <existing cycle count>`, `total_sprints: <count from spec>` on next read. The migration is idempotent.
- Cite `concepts/yoke-pattern-ralph-loop`, `concepts/yoke-pattern-memory-model`.

## Validation

- Static smoke: `progress.md` template (or seed) contains `current_sprint:`, `completed_sprints:`, `cycle_count:`, `total_sprints:` frontmatter fields.
- Functional smoke: invoke `/yoke:implement` from a clean state on a 3-sprint slug; after sprint 1 converges, assert `progress.md` has `current_sprint: 02`, `completed_sprints: [01]`, `cycle_count: 0`, and a `## Sprint 01` section with the cycle entries from sprint 1.
- File-singleton smoke: at no point does the runtime create `progress-s01.md` or any other per-sprint progress file. `find .yoke/runtime -name 'progress*.md'` returns exactly one match (`progress.md`).
- Migration smoke: starting from a `progress.md` lacking the new fields, on next read the file is updated in place with the new fields seeded; the existing body is preserved.

## Acceptance criterion

`grep -E "^current_sprint:" .yoke/runtime/progress.md && grep -E "^completed_sprints:" .yoke/runtime/progress.md && [ "$(find .yoke/runtime -maxdepth 1 -name 'progress*.md' -type f | wc -l)" = "1" ]` exits 0 (when invoked after a fresh `/yoke:implement` cycle).
