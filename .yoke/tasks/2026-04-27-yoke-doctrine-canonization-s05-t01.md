---
task_id: 2026-04-27-yoke-doctrine-canonization-s05-t01
sprint: 5
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s05-t01 — Implement and register the validation sensor that fails on any `.vibeflow/` reference under the framework surface.

## Story

The "zero `.vibeflow/` references" invariant from the PRD has to be
enforceable forever, not just at the end of v0. A bash sensor under
`lib/sensors/` makes the invariant a deterministic check that any
future Yoke change re-runs — caught by the Validator if a regression
sneaks in. Sprint 4 brings the count to 0; this sensor pins it.

## Technical implementation

- Create `lib/sensors/no-vibeflow-refs.sh`:
  ```bash
  #!/bin/bash
  # Sensor: zero .vibeflow/ references in framework surface.
  # Exits 0 if no matches; non-zero with file:line:context output otherwise.
  set -euo pipefail
  matches="$(grep -rnF '.vibeflow/' skills/ agents/ hooks/ lib/ templates/ 2>/dev/null || true)"
  if [[ -n "$matches" ]]; then
    echo "$matches" >&2
    echo "sensor: no-vibeflow-refs found $(echo "$matches" | wc -l) match(es)" >&2
    exit 1
  fi
  exit 0
  ```
- Make the script executable: `chmod +x lib/sensors/no-vibeflow-refs.sh`.
- Register in `/yoke:ack-sensors`: add the sensor to the catalog so it appears in catalog-mode output AND so Acceptance Contracts can declare it.
- Add a self-test at `tests/sensors/no-vibeflow-refs.test.sh` that:
  - Runs the sensor against the current tree; expects exit 0 (post-cutover state).
  - Creates a temp file under `skills/` containing `.vibeflow/`, runs the sensor; expects non-zero exit and the file:line in output. Cleans up the temp file.
  - Both cases are isolated; the test does not pollute the working tree.
- Wire the test into `tests/run-all.sh` (or whatever the smoke runner is) so CI exercises it.

## Validation

- `bash lib/sensors/no-vibeflow-refs.sh` exits 0 against the post-cutover tree.
- `bash tests/sensors/no-vibeflow-refs.test.sh` exits 0 (both pass and fail paths exercised).
- `bash skills/ack-sensors/SKILL.md`-driven catalog mode (or whatever invocation the skill exposes) lists `no-vibeflow-refs` as a registered sensor.
- The sensor file has executable permission.

## Acceptance criterion

`bash lib/sensors/no-vibeflow-refs.sh` exits 0 AND `bash tests/sensors/no-vibeflow-refs.test.sh` exits 0 AND `[ -x lib/sensors/no-vibeflow-refs.sh ]` returns 0.
