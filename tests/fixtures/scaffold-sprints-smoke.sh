#!/usr/bin/env bash
# scaffold-sprints-smoke.sh — fixture used by the
# `scaffold-sprints-functional` sensor in
# `.yoke/acceptance-contracts/2026-04-27-sprint-as-cycle.md`.
#
# Creates a synthetic spec under /tmp with a wm_validate_slug-compliant
# basename (date-prefixed), invokes lib/working-memory/scaffold-sprints.sh
# against it, asserts a sprint file is created and a re-run conflicts.
# Cleans up after itself.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

# Date-prefixed slug per WM_SLUG_REGEX.
SLUG="2026-04-27-scaffold-sprints-smoke-$$"
TMP_SPEC="/tmp/${SLUG}.md"
SPRINT_PATH=".yoke/sprints/${SLUG}-s01.md"

cleanup() {
  rm -f "$TMP_SPEC" "$SPRINT_PATH"
}
trap cleanup EXIT

cat > "$TMP_SPEC" <<EOF
---
slug: ${SLUG}
status: approved
---

# Spec: scaffold-sprints smoke fixture

### Sprint 1 — Test
Delivery objective: smoke fixture.

EOF

# First run: must succeed and create the sprint file.
if ! bash lib/working-memory/scaffold-sprints.sh "$TMP_SPEC" >/dev/null 2>&1; then
  echo "FAIL: scaffold-sprints.sh exited non-zero on clean run" >&2
  exit 1
fi
if [ ! -f "$SPRINT_PATH" ]; then
  echo "FAIL: expected sprint file at $SPRINT_PATH was not created" >&2
  exit 1
fi

# Second run: must refuse to overwrite (non-zero exit).
if bash lib/working-memory/scaffold-sprints.sh "$TMP_SPEC" >/dev/null 2>&1; then
  echo "FAIL: scaffold-sprints.sh did not refuse to overwrite existing file" >&2
  exit 1
fi

echo "PASS: scaffold-sprints.sh creates sprint files and refuses overwrite"
