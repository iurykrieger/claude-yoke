#!/usr/bin/env bash
# tests/lib/persona-mode-tag-sensor.test.sh
#
# Happy-path + negative coverage for the persona-mode-tag CI sensor
# added by the /yoke:fix Phase-1-entrypoint PRD (Sprint 03, Task t02):
#
#   tests/sensors/persona-mode-tag.test.sh
#     Walks an in-scope catalog of engineering-flavored skill bodies
#     (initial: skills/fix/SKILL.md and skills/tech-spec/SKILL.md) and
#     asserts each declares a well-formed Mode tag matching the regex
#     ^\*\*Mode:\*\*\s+(diagnose-first|design-first|review-first|
#     stabilize-first|rollback-first)\s*$ as the first non-empty line
#     under "## Your role".
#
# Anchors:
#   - PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-2)
#   - Acceptance Criteria (binding):
#       .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#       (AC-001-2, AC-005-2)
#   - Sprint task: 2026-05-05-phase-1-fix-entrypoint-s03-t02
#
# The test exercises the real sensor against the live repo (positive
# branch — both skills currently carry the Mode tag) and against tmpdir
# fixtures (negative branches — missing tag, malformed tag, missing
# skill file).
#
# Watchdog convention (concepts/yoke-conventions): smoke / runtime tests
# must guard against ralph-loop iterations or LLM-driven steps without
# hard bounds.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SENSOR="${REPO_ROOT}/tests/sensors/persona-mode-tag.test.sh"

FAIL=0
PASS_COUNT=0

fail() { echo "FAIL: $*" >&2; FAIL=1; }
pass() { echo "PASS: $*"; PASS_COUNT=$((PASS_COUNT + 1)); }

[ -x "$SENSOR" ] || chmod +x "$SENSOR"

# --- (a) live-repo positive branch ----------------------------------------
# Both skills carry the Mode tag in the live repo state — the sensor must
# exit 0.
set +e
out="$(bash "$SENSOR" 2>&1)"
ec=$?
set -e
if [ "$ec" -eq 0 ]; then
  pass "(a) live-repo: sensor exits 0 with both skills carrying Mode tag"
else
  fail "(a) live-repo: sensor exited ${ec}, expected 0"
  echo "stdout/stderr:" >&2
  printf '%s\n' "$out" | head -20 >&2
fi

# Subsequent negative cases isolate the sensor against fixture skills by
# running the sensor in a fixture clone of the repo. This avoids mutating
# the live skill bodies.
mk_fixture_dir() {
  local d
  d="$(mktemp -d)"
  mkdir -p "${d}/skills/fix" "${d}/skills/tech-spec" "${d}/tests/sensors"
  # Copy the live sensor body so paths inside it resolve against the
  # fixture's REPO_ROOT (the sensor uses BASH_SOURCE-relative cd).
  cp "$SENSOR" "${d}/tests/sensors/persona-mode-tag.test.sh"
  chmod +x "${d}/tests/sensors/persona-mode-tag.test.sh"
  echo "$d"
}

# --- (b) negative: missing Mode tag in skills/fix/SKILL.md ----------------
fixdir="$(mk_fixture_dir)"
cat > "${fixdir}/skills/fix/SKILL.md" <<'EOF'
---
name: fix
description: stub
allowed-tools: Read
---

# /yoke:fix

## Your role (Senior Engineer persona, inline)

Some prose with no Mode tag here.
EOF
cat > "${fixdir}/skills/tech-spec/SKILL.md" <<'EOF'
---
name: tech-spec
description: stub
allowed-tools: Read
---

# /yoke:tech-spec

## Your role (Senior Engineer persona, inline)

**Mode:** design-first

Body.
EOF
set +e
out="$(bash "${fixdir}/tests/sensors/persona-mode-tag.test.sh" 2>&1)"
ec=$?
set -e
if [ "$ec" -ne 0 ] && echo "$out" | grep -qE 'FAIL: skills/fix/SKILL\.md'; then
  pass "(b) negative: missing Mode tag in fix/SKILL.md trips the sensor"
else
  fail "(b) negative: expected non-zero exit + 'FAIL: skills/fix/SKILL.md' in output, got ec=${ec}"
  printf '%s\n' "$out" | head -20 >&2
fi
rm -rf "$fixdir"

# --- (c) negative: malformed Mode tag (unknown value) ---------------------
fixdir="$(mk_fixture_dir)"
cat > "${fixdir}/skills/fix/SKILL.md" <<'EOF'
---
name: fix
description: stub
allowed-tools: Read
---

# /yoke:fix

## Your role (Senior Engineer persona, inline)

**Mode:** debug-first

Body.
EOF
cat > "${fixdir}/skills/tech-spec/SKILL.md" <<'EOF'
---
name: tech-spec
description: stub
allowed-tools: Read
---

# /yoke:tech-spec

## Your role (Senior Engineer persona, inline)

**Mode:** design-first

Body.
EOF
set +e
out="$(bash "${fixdir}/tests/sensors/persona-mode-tag.test.sh" 2>&1)"
ec=$?
set -e
if [ "$ec" -ne 0 ] && echo "$out" | grep -q 'debug-first'; then
  pass "(c) negative: unknown Mode value (debug-first) trips the sensor with observed line in output"
else
  fail "(c) negative: expected non-zero exit + observed 'debug-first' in output, got ec=${ec}"
  printf '%s\n' "$out" | head -20 >&2
fi
rm -rf "$fixdir"

# --- (d) negative: missing skill file -------------------------------------
fixdir="$(mk_fixture_dir)"
# Create only tech-spec, not fix
cat > "${fixdir}/skills/tech-spec/SKILL.md" <<'EOF'
---
name: tech-spec
description: stub
allowed-tools: Read
---

# /yoke:tech-spec

## Your role (Senior Engineer persona, inline)

**Mode:** design-first

Body.
EOF
set +e
out="$(bash "${fixdir}/tests/sensors/persona-mode-tag.test.sh" 2>&1)"
ec=$?
set -e
if [ "$ec" -ne 0 ] && echo "$out" | grep -qE 'FAIL: skills/fix/SKILL\.md' && echo "$out" | grep -q 'does not exist'; then
  pass "(d) negative: missing skills/fix/SKILL.md trips the sensor with explicit 'does not exist' guidance"
else
  fail "(d) negative: expected non-zero exit + missing-file diagnostic, got ec=${ec}"
  printf '%s\n' "$out" | head -20 >&2
fi
rm -rf "$fixdir"

# --- (e) positive: open-vocabulary value (review-first) accepted ----------
fixdir="$(mk_fixture_dir)"
cat > "${fixdir}/skills/fix/SKILL.md" <<'EOF'
---
name: fix
description: stub
allowed-tools: Read
---

# /yoke:fix

## Your role (Senior Engineer persona, inline)

**Mode:** diagnose-first

Body.
EOF
cat > "${fixdir}/skills/tech-spec/SKILL.md" <<'EOF'
---
name: tech-spec
description: stub
allowed-tools: Read
---

# /yoke:tech-spec

## Your role (Senior Engineer persona, inline)

**Mode:** review-first

Body.
EOF
set +e
out="$(bash "${fixdir}/tests/sensors/persona-mode-tag.test.sh" 2>&1)"
ec=$?
set -e
if [ "$ec" -eq 0 ]; then
  pass "(e) positive: open-vocabulary 'review-first' accepted (regex covers full ratified set)"
else
  fail "(e) positive: expected exit 0 with review-first, got ec=${ec}"
  printf '%s\n' "$out" | head -20 >&2
fi
rm -rf "$fixdir"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "--- persona-mode-tag-sensor: ALL PASS (${PASS_COUNT}/5) ---"
  exit 0
else
  echo "--- persona-mode-tag-sensor: FAILURES ABOVE ---" >&2
  exit 1
fi
