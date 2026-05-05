#!/usr/bin/env bash
# tests/lib/wm_set_active_phase1_invariant.test.sh
#
# FR-9a "exactly one Phase-1 artifact per slug" invariant on write —
# regression coverage for the wm_set_active extension added by Sprint 02
# / Task t02 of the /yoke:fix Phase-1-entrypoint PRD.
#
# Behavior under test:
#   wm_set_active "<slug>"
#     - Validates the slug regex (existing contract).
#     - NEW: refuses to record .yoke/runtime/.current when both
#       .yoke/prds/<slug>.md and .yoke/fixes/<slug>.md exist for the
#       slug. On refusal: prints the FR-9 ambiguous-Phase-1-state
#       diagnostic verbatim to stderr, exits non-zero, and leaves
#       .yoke/runtime/.current unchanged.
#     - All previous happy-path semantics are preserved (creates
#       runtime dir lazily, writes the slug, returns 0) when the
#       invariant holds.
#
# Anchors:
#   - PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-9a)
#   - Spec: .yoke/specs/2026-05-05-phase-1-fix-entrypoint.md
#       (Technical Considerations / FR-9a sub-case)
#   - Acceptance Criteria (binding):
#       .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#       (US-004 DoD bullet, AC-004-3)
#   - Sprint task: 2026-05-05-phase-1-fix-entrypoint-s02-t02
#
# Watchdog convention (concepts/yoke-conventions): mandatory framework
# infrastructure even for fast unit-tier tests.

set -euo pipefail

# Watchdog — kill the test process tree at 10 minutes flat.
sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
# tests/lib/wm_set_active_phase1_invariant.test.sh -> ../..
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Source the harness for pass/err/summary helpers.
source "$REPO_ROOT/tests/lib/harness.sh"

PATHS_LIB="$REPO_ROOT/lib/working-memory/paths.sh"
if [[ ! -f "$PATHS_LIB" ]]; then
  err "missing paths.sh at $PATHS_LIB"
  harness::summary
fi

VALID_SLUG="2026-01-01-foo"

# ---------------------------------------------------------------------------
# Case (a) — Happy path retained: only one Phase-1 artifact exists, the
#   slug is regex-valid, and wm_set_active records the slug into
#   .yoke/runtime/.current with rc=0.
# Anchors AC-004-3's "leaves .current unmodified" precondition by first
# proving the happy path WRITES .current as expected (so the negative
# branch's "unmodified" assertion has a meaningful baseline).
# ---------------------------------------------------------------------------
TMP_A=$(mktemp -d)

set +e
(
  cd "$TMP_A"
  mkdir -p ".yoke/prds"
  printf '# stub PRD\n' > ".yoke/prds/${VALID_SLUG}.md"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_set_active "$VALID_SLUG"
)
A_RC=$?
set -e

A_CURRENT="$TMP_A/.yoke/runtime/.current"
A_RECORDED=""
if [[ -f "$A_CURRENT" ]]; then
  A_RECORDED="$(cat "$A_CURRENT")"
fi

if [[ "$A_RC" -eq 0 ]] && [[ "$A_RECORDED" == "$VALID_SLUG" ]]; then
  pass "(a) happy path retained: wm_set_active records slug when only one Phase-1 artifact exists"
else
  err "(a) happy path broke rc=$A_RC recorded='$A_RECORDED' expected='$VALID_SLUG'"
fi

rm -rf "$TMP_A"

# ---------------------------------------------------------------------------
# Case (b) — FR-9a invariant: both PRD and fix-spec exist → refusal.
#   Asserts:
#     - exit non-zero (refusal).
#     - stderr starts with the verbatim ratified header
#       "wm: ambiguous Phase-1 state for slug '<slug>'".
#     - stderr carries the FR-9 diagnostic body (both paths, the
#       "first 100 bytes:" excerpt label, the "last commit:" label,
#       the "git rm" recipe).
#     - .yoke/runtime/.current is NOT created (the file does not exist
#       on refusal because no prior wm_set_active call ran).
# Anchors AC-004-3.
# ---------------------------------------------------------------------------
TMP_B=$(mktemp -d)
B_ERR="$TMP_B/stderr"

set +e
(
  cd "$TMP_B"
  mkdir -p ".yoke/prds" ".yoke/fixes"
  printf '# stub PRD\n' > ".yoke/prds/${VALID_SLUG}.md"
  printf '# stub fix-spec\n' > ".yoke/fixes/${VALID_SLUG}.md"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_set_active "$VALID_SLUG"
) 2>"$B_ERR"
B_RC=$?
set -e

B_STDERR="$(cat "$B_ERR")"
B_HEADER="wm: ambiguous Phase-1 state for slug '${VALID_SLUG}'"
B_CURRENT="$TMP_B/.yoke/runtime/.current"

# .current MUST NOT have been written. Two acceptable shapes:
#   1. .yoke/runtime/ does not exist (no prior write created it).
#   2. .yoke/runtime/ exists but .current is absent.
B_CURRENT_ABSENT=0
if [[ ! -f "$B_CURRENT" ]]; then
  B_CURRENT_ABSENT=1
fi

if [[ "$B_RC" -ne 0 ]] \
  && [[ "$B_STDERR" == *"$B_HEADER"* ]] \
  && [[ "$B_STDERR" == *".yoke/prds/${VALID_SLUG}.md"* ]] \
  && [[ "$B_STDERR" == *".yoke/fixes/${VALID_SLUG}.md"* ]] \
  && [[ "$B_STDERR" == *"first 100 bytes:"* ]] \
  && [[ "$B_STDERR" == *"last commit:"* ]] \
  && [[ "$B_STDERR" == *"git rm"* ]] \
  && [[ "$B_CURRENT_ABSENT" -eq 1 ]]; then
  pass "(b) FR-9a refusal: wm_set_active aborts on both-exist + leaves .current unmodified + emits FR-9 diagnostic"
else
  err "(b) FR-9a refusal misbehaved rc=$B_RC current_absent=$B_CURRENT_ABSENT stderr=<<<$B_STDERR>>>"
fi

rm -rf "$TMP_B"

# ---------------------------------------------------------------------------
# Case (c) — FR-9a invariant preserves PRE-EXISTING .current on refusal:
#   wm_set_active was previously called with a different (valid) slug;
#   .current carries that prior slug. The new call hits the both-exist
#   refusal — .current MUST keep the prior slug verbatim.
# Anchors AC-004-3 "leaves .current unmodified" — the strict reading of
# the AC is that an EXISTING .current is preserved byte-for-byte across
# a refusing call.
# ---------------------------------------------------------------------------
TMP_C=$(mktemp -d)
PRIOR_SLUG="2026-01-01-priorslug"

set +e
(
  cd "$TMP_C"
  # First, set .current to a clean slug — this is the baseline.
  mkdir -p ".yoke/prds"
  printf '# stub prior PRD\n' > ".yoke/prds/${PRIOR_SLUG}.md"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_set_active "$PRIOR_SLUG"
)
C_BASELINE_RC=$?

# Now create both PRD + fix-spec for the conflict slug and try wm_set_active.
set +e
(
  cd "$TMP_C"
  mkdir -p ".yoke/prds" ".yoke/fixes"
  printf '# stub conflict PRD\n' > ".yoke/prds/${VALID_SLUG}.md"
  printf '# stub conflict fix-spec\n' > ".yoke/fixes/${VALID_SLUG}.md"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_set_active "$VALID_SLUG"
) 2>/dev/null
C_REFUSE_RC=$?
set -e

C_CURRENT="$TMP_C/.yoke/runtime/.current"
C_RECORDED=""
if [[ -f "$C_CURRENT" ]]; then
  C_RECORDED="$(cat "$C_CURRENT")"
fi

if [[ "$C_BASELINE_RC" -eq 0 ]] \
  && [[ "$C_REFUSE_RC" -ne 0 ]] \
  && [[ "$C_RECORDED" == "$PRIOR_SLUG" ]]; then
  pass "(c) FR-9a preserves pre-existing .current verbatim across refusal (prior='$PRIOR_SLUG' kept)"
else
  err "(c) FR-9a .current preservation broke baseline_rc=$C_BASELINE_RC refuse_rc=$C_REFUSE_RC recorded='$C_RECORDED' expected_prior='$PRIOR_SLUG'"
fi

rm -rf "$TMP_C"

# ---------------------------------------------------------------------------
# Case (d) — Slug-validation precedes the invariant check: an INVALID
#   slug aborts with the existing wm:-prefixed slug-validation
#   diagnostic, regardless of disk state.
# Regression case for the existing slug-validation contract — proving
# the new invariant gate did not displace the existing boundary check.
# ---------------------------------------------------------------------------
TMP_D=$(mktemp -d)
D_ERR="$TMP_D/stderr"

set +e
(
  cd "$TMP_D"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_set_active "INVALID SLUG"
) 2>"$D_ERR"
D_RC=$?
set -e

D_STDERR="$(cat "$D_ERR")"

if [[ "$D_RC" -ne 0 ]] && [[ "$D_STDERR" == wm:* ]]; then
  pass "(d) invalid slug still aborts with 'wm:'-prefixed slug-validation diagnostic (existing contract preserved)"
else
  err "(d) slug-validation regression rc=$D_RC stderr='$D_STDERR'"
fi

rm -rf "$TMP_D"

harness::summary
