#!/usr/bin/env bash
# tests/smoke/acceptance-criteria-shape.test.sh
#
# Smoke gate for the new-flow acceptance-criteria shape. Anchors:
#   - Sprint 01, task t05 (PRD: 2026-05-03-generate-sprints-skill).
#   - Acceptance Contract Scenario 5
#     (`tests/fixtures/acceptance-criteria/{valid.md,invalid-task-ids.md,
#      invalid-no-uc.md}`).
#
# Three assertion blocks exercise the shape-checker
# `tests/acceptance/2026-05-03-generate-sprints-skill/_lib/check-shape.sh`
# (relocated from lib/working-memory/ in cycle 1 — see the helper's own
# lineage comment for context):
#   1. Valid fixture                -> checker exits 0.
#   2. Invalid task-IDs fixture     -> checker exits non-zero,
#                                       stderr contains
#                                       `wm: forbidden task-ID reference`.
#   3. Invalid missing-UC fixture   -> checker exits non-zero,
#                                       stderr contains
#                                       `wm: no UC headings found`.
#
# Each block prints a single line starting with `PASS:` on success.
# The test exits 0 only when all three blocks pass.
#
# Watchdog convention (concepts/yoke-conventions): smoke tests must
# guard against ralph-loop iterations or LLM-driven steps without
# hard bounds. None of the three blocks invokes an agent, but the
# watchdog is a non-negotiable framework convention.

set -euo pipefail

# Watchdog — kill the test process tree at 10 minutes flat.
sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

CHECKER="$REPO_ROOT/tests/acceptance/2026-05-03-generate-sprints-skill/_lib/check-shape.sh"
FIX_DIR="$REPO_ROOT/tests/fixtures/acceptance-criteria"

VALID_FIX="$FIX_DIR/valid.md"
INVALID_TASK_IDS_FIX="$FIX_DIR/invalid-task-ids.md"
INVALID_NO_UC_FIX="$FIX_DIR/invalid-no-uc.md"

# Pre-flight — fail fast with a clear diagnostic if the inputs are missing.
for f in "$CHECKER" "$VALID_FIX" "$INVALID_TASK_IDS_FIX" "$INVALID_NO_UC_FIX"; do
  if [[ ! -f "$f" ]]; then
    printf 'FAIL: missing input %s\n' "$f" >&2
    exit 1
  fi
done

FAIL=0

# ---------------------------------------------------------------------------
# Block 1 — valid fixture: shape-checker MUST exit 0.
# ---------------------------------------------------------------------------
if bash "$CHECKER" "$VALID_FIX" >/dev/null 2>/tmp/ac-shape-valid.err; then
  printf 'PASS: valid fixture accepted by shape-checker\n'
else
  rc=$?
  printf 'FAIL: valid fixture rejected (rc=%d)\n' "$rc" >&2
  printf '       stderr: %s\n' "$(cat /tmp/ac-shape-valid.err)" >&2
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Block 2 — invalid task-IDs fixture: shape-checker MUST exit non-zero
#           AND stderr MUST contain `wm: forbidden task-ID reference`.
# ---------------------------------------------------------------------------
if bash "$CHECKER" "$INVALID_TASK_IDS_FIX" >/dev/null 2>/tmp/ac-shape-tids.err; then
  printf 'FAIL: invalid-task-ids fixture incorrectly accepted\n' >&2
  FAIL=1
else
  if grep -q 'wm: forbidden task-ID reference' /tmp/ac-shape-tids.err; then
    printf 'PASS: invalid task-IDs fixture rejected with documented stderr\n'
  else
    printf 'FAIL: invalid-task-ids fixture rejected but stderr missing literal\n' >&2
    printf '       stderr: %s\n' "$(cat /tmp/ac-shape-tids.err)" >&2
    FAIL=1
  fi
fi

# ---------------------------------------------------------------------------
# Block 3 — invalid no-UC fixture: shape-checker MUST exit non-zero
#           AND stderr MUST contain `wm: no UC headings found`.
# ---------------------------------------------------------------------------
if bash "$CHECKER" "$INVALID_NO_UC_FIX" >/dev/null 2>/tmp/ac-shape-nouc.err; then
  printf 'FAIL: invalid-no-uc fixture incorrectly accepted\n' >&2
  FAIL=1
else
  if grep -q 'wm: no UC headings found' /tmp/ac-shape-nouc.err; then
    printf 'PASS: missing-UC fixture rejected with documented stderr\n'
  else
    printf 'FAIL: invalid-no-uc fixture rejected but stderr missing literal\n' >&2
    printf '       stderr: %s\n' "$(cat /tmp/ac-shape-nouc.err)" >&2
    FAIL=1
  fi
fi

# Cleanup tmp stderr captures.
rm -f /tmp/ac-shape-valid.err /tmp/ac-shape-tids.err /tmp/ac-shape-nouc.err

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL\n' >&2
  exit 1
fi

printf '\n--- Result ---\nPASS (3 blocks)\n'
exit 0
