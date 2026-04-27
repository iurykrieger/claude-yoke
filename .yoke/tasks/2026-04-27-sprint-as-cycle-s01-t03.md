---
task_id: 2026-04-27-sprint-as-cycle-s01-t03
sprint: 1
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-1
---

# Task 2026-04-27-sprint-as-cycle-s01-t03 — Add `lib/working-memory/scaffold-sprints.sh` parsing sprint headings from a spec file and seeding one empty sprint file per `<slug>-s<NN>` ID (replaces `scaffold-tasks.sh` in sprint 3).

## Story

`scaffold-tasks.sh` is the deterministic stage-2 bracket that bounds the LLM stages of `/yoke:tech-spec`. The sprint-as-cycle shape needs a peer scaffolder that creates sprint files instead of task files. Authoring it in sprint 1 (additive) means sprint 3's `/yoke:tech-spec` rewrite can swap callsites cleanly without first having to author the helper. The old scaffolder remains untouched and operational this sprint; both coexist until sprint 3 retires the task-shape one.

## Technical implementation

- Create `lib/working-memory/scaffold-sprints.sh` next to `lib/working-memory/scaffold-tasks.sh`.
- Shape (mirroring `scaffold-tasks.sh`):
  - Shebang: `#!/usr/bin/env bash`. `set -euo pipefail`.
  - Argument: `<spec_path>` — absolute or relative path to a `.yoke/specs/<slug>.md`.
  - Extract `<slug>` from the basename of `<spec_path>` (strip leading directories and trailing `.md`).
  - Parse sprint headings from the spec body via the deterministic regex `^### Sprint ([0-9]+) — `. The captured group is the sprint number; reject values outside 1–99 with `wm: invalid sprint number <N> in <path>`.
  - For each sprint number found, compute the zero-padded `<NN>` and the target path `.yoke/sprints/<slug>-s<NN>.md`. Skip if the file already exists (refuse to overwrite — exit non-zero with `wm: would overwrite existing sprint file at <path>`, listing all conflicts).
  - Lazily `mkdir -p .yoke/sprints/`.
  - Seed each new sprint file from `templates/sprint.md` with substitutions: `<slug>` → actual slug, `<NN>` → padded sprint number, `<N>` → unpadded sprint number, `<iso8601>` → `date -u +%Y-%m-%dT%H:%M:%SZ`. Leave body section bodies empty (or with the placeholder text from the template).
  - On success: emit `wm: scaffolded <count> sprint file(s) under .yoke/sprints/` to stdout, exit 0.
- Cite `concepts/yoke-pattern-plugin-structure` for the lib/ layout convention.

## Validation

- Smoke: invoke `bash lib/working-memory/scaffold-sprints.sh /tmp/test-spec.md` (where `/tmp/test-spec.md` contains `### Sprint 1 — Test\n### Sprint 2 — Two\n### Sprint 3 — Three\n### Sprint 4 — Four\n` plus a valid frontmatter) from a clean state. Assert that 4 files are created (`-s01.md` through `-s04.md`) and the script exits 0 with the expected `wm: scaffolded 4 sprint file(s)` message.
- Idempotency smoke: re-running the same command exits non-zero with the conflict list.
- Negative smoke: invoke against a spec file that contains `### Sprint 0 — …` or `### Sprint 100 — …` and assert the script exits non-zero.
- Frontmatter smoke: read one of the seeded files and assert `task_id: <slug>-s01`, `sprint: 1`, `slug: <slug>`, `status: draft` are present.
- This task does NOT invoke the scaffolder against the active spec at fill time — the script must be runnable but not auto-run during stage 3 of this PRD.

## Acceptance criterion

`bash lib/working-memory/scaffold-sprints.sh /tmp/test-spec.md` (where `/tmp/test-spec.md` is a freshly-authored fixture containing exactly one `### Sprint 1 — Test` heading and a valid frontmatter) creates `.yoke/sprints/<slug>-s01.md` matching `templates/sprint.md`'s shape, exits 0 with `wm: scaffolded 1 sprint file(s)…` on stdout; the immediate re-run exits non-zero with the conflict message.
