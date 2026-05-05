#!/usr/bin/env bash
# criterion: AC-005-2
#
# AC-005-2 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "The persona-mode-tag sensor (per AC-001-2) walks every
#    engineering-flavored skill body and asserts each declares a
#    well-formed Mode tag; the sensor's catalog at
#    tests/sensors/persona-mode-tag.test.sh lists skills/fix/SKILL.md
#    and skills/tech-spec/SKILL.md as in-scope and exits 0 in CI."
#
# Sprint scope (s03-t02): Sr Eng authors
# tests/sensors/persona-mode-tag.test.sh, wires it into
# .github/workflows/tests.yml, and asserts each engineering-flavored
# skill body declares a well-formed Mode tag matching the regex
# `^\*\*Mode:\*\*\s+(diagnose-first|design-first|review-first|stabilize-first|rollback-first)\s*$`
# on the first line under "Your role".
#
# This binding test invokes Sr Eng's sensor directly and asserts:
#   (1) the sensor file exists at tests/sensors/persona-mode-tag.test.sh
#   (2) the sensor file is executable
#   (3) the sensor's catalog of in-scope skill bodies includes
#       skills/fix/SKILL.md AND skills/tech-spec/SKILL.md (verbatim
#       PRD FR-2 / AC-005-2 catalog requirement)
#   (4) running the sensor exits 0 (the sensor's own self-test against
#       the current skill bodies passes)

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

SENSOR_PATH="$REPO_ROOT/tests/sensors/persona-mode-tag.test.sh"

# ---------------------------------------------------------------------------
# Case (1) — sensor file exists.
# ---------------------------------------------------------------------------
if [[ -f "$SENSOR_PATH" ]]; then
  pass "(1) tests/sensors/persona-mode-tag.test.sh exists"
else
  err "(1) tests/sensors/persona-mode-tag.test.sh is missing — Sr Eng s03-t02 deliverable"
  harness::summary
fi

# ---------------------------------------------------------------------------
# Case (2) — sensor file is executable.
# ---------------------------------------------------------------------------
if [[ -x "$SENSOR_PATH" ]]; then
  pass "(2) tests/sensors/persona-mode-tag.test.sh is executable"
else
  err "(2) tests/sensors/persona-mode-tag.test.sh exists but is not executable (chmod +x missing)"
fi

# ---------------------------------------------------------------------------
# Case (3) — sensor catalog references both skill bodies.
#
# AC-005-2 mandates the sensor's in-scope catalog list includes both
# skills/fix/SKILL.md and skills/tech-spec/SKILL.md. The catalog form
# is implementation-defined (could be an array, hard-coded paths,
# walks the skills/ tree filtering, etc.) — we pin only that both
# substrings appear in the sensor source.
# ---------------------------------------------------------------------------
SENSOR_BODY="$(cat "$SENSOR_PATH" 2>/dev/null || true)"

if grep -q "skills/fix/SKILL.md" <<<"$SENSOR_BODY" && \
   grep -q "skills/tech-spec/SKILL.md" <<<"$SENSOR_BODY"; then
  pass "(3) sensor catalog references both skills/fix/SKILL.md and skills/tech-spec/SKILL.md"
else
  err "(3) sensor catalog missing one or both in-scope skill paths (skills/fix/SKILL.md, skills/tech-spec/SKILL.md)"
fi

# ---------------------------------------------------------------------------
# Case (4) — running the sensor exits 0.
#
# The sensor walks every engineering-flavored skill body and asserts
# each declares a well-formed Mode tag. Sprint 03's deliverables
# (s03-t01: backfill design-first into tech-spec; s03-t04: author
# skills/fix/SKILL.md with diagnose-first as first line under
# "Your role") together make the sensor pass. If either is missing
# or malformed, the sensor exits non-zero and this test reports it.
# ---------------------------------------------------------------------------
TMP_OUT=$(mktemp -d)
SENSOR_OUT="$TMP_OUT/stdout"
SENSOR_ERR="$TMP_OUT/stderr"

set +e
bash "$SENSOR_PATH" >"$SENSOR_OUT" 2>"$SENSOR_ERR"
SENSOR_RC=$?
set -e

if [[ "$SENSOR_RC" -eq 0 ]]; then
  pass "(4) tests/sensors/persona-mode-tag.test.sh exits 0 against current skill bodies"
else
  STDOUT_TAIL=$(tail -20 "$SENSOR_OUT" 2>/dev/null || true)
  STDERR_TAIL=$(tail -20 "$SENSOR_ERR" 2>/dev/null || true)
  err "(4) persona-mode-tag sensor exited rc=$SENSOR_RC; stdout-tail='$STDOUT_TAIL' stderr-tail='$STDERR_TAIL'"
fi

rm -rf "$TMP_OUT"

harness::summary
