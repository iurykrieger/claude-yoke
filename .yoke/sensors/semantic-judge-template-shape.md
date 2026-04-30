<!--
Migrated by .yoke/runtime/populate-from-registry.py on 2026-04-30 per
.yoke/prds/2026-04-30-sensor-harness-realignment.md (Sprint 3, t01).
Frontmatter populated from the binding Acceptance Contract's registry
(legacy-bootstrap shape); body sections in the new schema. Sprint 1
upsert created the file with `command: <!-- TODO: fill -->`; Sprint 3
populates command/type and the four-section body.
-->
---
id: semantic-judge-template-shape
type: computational
token_cost: 0
time_cost: 30
command: |
  f=templates/sensors/semantic-judge.md; [ -f "$f" ] && grep -q '^type: inferential$' "$f" && grep -q '^agent: semantic-judge$' "$f" && [ "$(grep -cE '^### (Prompt|Rubric|Verdict schema)$' "$f")" = "3" ]
---

# semantic-judge-template-shape

## How to run

Run the `command:` declared in the frontmatter from the repo root.
Non-zero exit equals sensor fail; the binding Acceptance Contract for
the source PRD declares the calibrated invocation.

## Known issues

- No known caveats yet — populated by `/yoke:consolidate-sensors` on
  evidence accumulation.

## Frequent errors

- TODO: pattern: TODO — fix.
