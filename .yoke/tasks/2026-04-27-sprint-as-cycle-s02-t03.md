---
task_id: 2026-04-27-sprint-as-cycle-s02-t03
sprint: 2
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-2
---

# Task 2026-04-27-sprint-as-cycle-s02-t03 — Reframe in-file headers in every migrated sprint file: `# Spec: ... — Part N (of M)?` becomes `# Sprint <NN> of <MM>: ...`; the leading `# Spec:` H1 is preserved as a body annotation, not a heading.

## Story

After t02 renames files, the H1 inside each migrated file still reads `# Spec: ... — Part N of M`. That heading misrepresents the new shape (which is "sprint", not "spec part") and confuses readers. This task rewrites those H1s to a consistent sprint-shaped form via deterministic regex on the migrated files. It also strips the `# Spec:` prefix so the H1 is a clean `# Sprint <NN> of <MM>: <title>`.

## Technical implementation

- Iterate every file under `.yoke/sprints/` matching `*-s[0-9][0-9].md` that has `Migrated-from:` empty or absent (i.e., the 62 files migrated in t02; sprint files freshly authored or migrated in t04 are out of scope).
- For each file, locate the H1 line (first `^# ` match in the body, after frontmatter). Apply the deterministic regex transform:
  - Pattern: `^# Spec:\s*(.+?)\s*[—-]\s*Part\s+(\d+)(?:\s+of\s+(\d+))?(.*?)$` (match titles like "# Spec: Foo — Part 3 of 6" or "# Spec: Foo — Part 3").
  - Replacement: `# Sprint <NN> of <MM>: <title>` where `<NN>` = zero-padded `\2`, `<MM>` = zero-padded `\3` (default to total sprint count for that slug if `\3` absent), `<title>` = `\1`. Append the original H1 as a body annotation block immediately after frontmatter: `> Migrated from: <original H1>`.
- For files whose H1 doesn't match the pattern (edge cases — e.g., the H1 doesn't say "Part N"): leave the H1 unchanged but emit a `wm: H1 reframe skipped at <path>` warning to stderr. The sensor in t05 will flag any unreframed file.
- Implement as a one-shot bash + sed (or perl for safer multi-line) script invoked inline within this task. Do NOT add a permanent script file under `lib/` — the reframe is one-shot.
- Commit the rewrites in one git commit with message `chore(working-memory): reframe H1 of migrated sprint files (Part N → Sprint NN)`. Two commits total for sprint 2 so far (t02 + t03), keeps the diff reviewable.

## Validation

- Reframe smoke: for `.yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s03.md`, the H1 reads `# Sprint 03 of 06: Bedrock canonical-memory port` (or similar; exact title carried from `\1`).
- Original-H1 preservation: the same file body contains a block `> Migrated from: # Spec: Bedrock canonical-memory port — Part 3: ...` immediately after frontmatter.
- Regex non-match smoke: any sprint file whose original H1 didn't match the pattern (edge cases) emits the warning to stderr but is not modified, and the sensor in t05 flags the path.
- Diff smoke: `git diff HEAD~1 -- .yoke/sprints/*.md` for this commit shows H1 changes only — no body changes outside the H1 line and the appended `> Migrated from:` annotation.
- Spot check: 5 random migrated files have correctly-reframed H1s.

## Acceptance criterion

`grep -lE "^# Spec:.*Part [0-9]+( of [0-9]+)?$" .yoke/sprints/*.md` returns zero matches (no migrated file retains the legacy H1), AND `grep -lE "^# Sprint [0-9]{2}( of [0-9]{2})?:" .yoke/sprints/*.md | wc -l` returns ≥ `62`.
