# Fixtures: parse-inputs

Two acceptance-criteria fixtures consumed by
`tests/acceptance/2026-05-03-generate-sprints-skill/us-003-parse-inputs-shape.test.sh`.

- `happy.md` — two well-formed `### US-` blocks. Drives the
  positive-branch assertions: parser emits valid JSON whose array
  length equals 2.
- `malformed-us.md` — first block well-formed, second block missing
  `**Definition of Done:**`. Drives the negative-branch assertion:
  parser exits non-zero with `wm:`-prefixed stderr.

The post-rename canonical shape (`### US-<NNN>`) is used per the
binding contract (PRD US-002 + US-003). The legacy `### UC-<n>`
shape is accepted by the shape-checker for back-compat but the
fixtures here are anchored to the canonical shape.
