#!/usr/bin/env bash
# tests/lib/wm_phase1_artifact_path.test.sh
#
# Happy-path + negative coverage for the new existence-aware resolver
# added by the /yoke:fix Phase-1-entrypoint PRD (Sprint 02, Task t01):
#
#   wm_phase1_artifact_path "<slug>"
#     Returns the existing Phase-1 artifact path on the unambiguous case
#     (exactly one of .yoke/prds/<slug>.md or .yoke/fixes/<slug>.md
#     present); hard-aborts non-zero with the verbatim
#     "wm: ambiguous Phase-1 state for slug '<slug>'" structured-recovery
#     diagnostic when both exist; hard-aborts with the wm:-prefixed
#     neither-case diagnostic ending "Run /yoke:discover or /yoke:fix
#     first." when neither exists.
#
# This is the canonical I/O-aware exception in paths.sh — every other
# helper is a pure path computer. The contract does NOT propagate to
# future helpers.
#
# Anchors:
#   - PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-9)
#   - Spec: .yoke/specs/2026-05-05-phase-1-fix-entrypoint.md
#       (APIs and Data Model :: wm_phase1_artifact_path)
#   - Acceptance Criteria (binding):
#       .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#       (US-003 DoD bullet, US-004 DoD bullets, AC-004-1, AC-004-2)
#   - Sprint task: 2026-05-05-phase-1-fix-entrypoint-s02-t01
#
# The test sources `lib/working-memory/paths.sh` directly into a tmpdir
# CWD and exercises the helper without touching the host project's
# `.yoke/`. Every branch is covered in an isolated tmpdir so disk state
# under one branch does not leak into another.
#
# Watchdog convention (concepts/yoke-conventions): smoke / runtime tests
# must guard against ralph-loop iterations or LLM-driven steps without
# hard bounds. The watchdog is mandatory framework infrastructure even
# when the test body itself runs in milliseconds.

set -euo pipefail

# Watchdog — kill the test process tree at 10 minutes flat.
sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
# tests/lib/wm_phase1_artifact_path.test.sh -> ../..
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
# Case (a) — ONLY-PRD branch: only .yoke/prds/<slug>.md exists.
#   Asserts: exit 0, stdout is exactly ".yoke/prds/<slug>.md", stderr empty.
# Anchors AC-003-1 (resolver returns the existing PRD path on the
# unambiguous PRD-backed case).
# ---------------------------------------------------------------------------
TMP_A=$(mktemp -d)
A_OUT="$TMP_A/stdout"
A_ERR="$TMP_A/stderr"

set +e
(
  cd "$TMP_A"
  mkdir -p ".yoke/prds"
  printf '# stub PRD\n> Status: approved\n' > ".yoke/prds/${VALID_SLUG}.md"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "$VALID_SLUG"
) >"$A_OUT" 2>"$A_ERR"
A_RC=$?
set -e

A_STDOUT="$(cat "$A_OUT")"
A_STDERR="$(cat "$A_ERR")"
EXPECTED_PRD=".yoke/prds/${VALID_SLUG}.md"

if [[ "$A_RC" -eq 0 && "$A_STDOUT" == "$EXPECTED_PRD" && -z "$A_STDERR" ]]; then
  pass "(a) only-PRD: resolver returns '$EXPECTED_PRD' (rc=0, stderr empty)"
else
  err "(a) only-PRD branch misbehaved rc=$A_RC stdout='$A_STDOUT' stderr='$A_STDERR'"
fi

rm -rf "$TMP_A"

# ---------------------------------------------------------------------------
# Case (b) — ONLY-FIX branch: only .yoke/fixes/<slug>.md exists.
#   Asserts: exit 0, stdout is exactly ".yoke/fixes/<slug>.md", stderr empty.
# Anchors AC-003-3 (resolver returns the existing fix-spec path on the
# unambiguous fix-backed case).
# ---------------------------------------------------------------------------
TMP_B=$(mktemp -d)
B_OUT="$TMP_B/stdout"
B_ERR="$TMP_B/stderr"

set +e
(
  cd "$TMP_B"
  mkdir -p ".yoke/fixes"
  printf '# stub fix-spec\n> Status: approved\n' > ".yoke/fixes/${VALID_SLUG}.md"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "$VALID_SLUG"
) >"$B_OUT" 2>"$B_ERR"
B_RC=$?
set -e

B_STDOUT="$(cat "$B_OUT")"
B_STDERR="$(cat "$B_ERR")"
EXPECTED_FIX=".yoke/fixes/${VALID_SLUG}.md"

if [[ "$B_RC" -eq 0 && "$B_STDOUT" == "$EXPECTED_FIX" && -z "$B_STDERR" ]]; then
  pass "(b) only-fix: resolver returns '$EXPECTED_FIX' (rc=0, stderr empty)"
else
  err "(b) only-fix branch misbehaved rc=$B_RC stdout='$B_STDOUT' stderr='$B_STDERR'"
fi

rm -rf "$TMP_B"

# ---------------------------------------------------------------------------
# Case (c) — NEITHER branch: no Phase-1 artifact for the slug.
#   Asserts: exit non-zero, stderr is wm:-prefixed AND ends with the
#            literal remediation 'Run /yoke:discover or /yoke:fix first.',
#            stdout is empty.
# Anchors AC-004-2.
# ---------------------------------------------------------------------------
TMP_C=$(mktemp -d)
C_OUT="$TMP_C/stdout"
C_ERR="$TMP_C/stderr"

set +e
(
  cd "$TMP_C"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "$VALID_SLUG"
) >"$C_OUT" 2>"$C_ERR"
C_RC=$?
set -e

C_STDOUT="$(cat "$C_OUT")"
C_STDERR="$(cat "$C_ERR")"

if [[ "$C_RC" -ne 0 ]] \
  && [[ "$C_STDERR" == wm:* ]] \
  && [[ "$C_STDERR" == *"Run /yoke:discover or /yoke:fix first."* ]] \
  && [[ -z "$C_STDOUT" ]]; then
  pass "(c) neither: resolver aborts with wm:-prefixed neither-case diagnostic + literal remediation"
else
  err "(c) neither branch misbehaved rc=$C_RC stdout='$C_STDOUT' stderr=<<<$C_STDERR>>>"
fi

rm -rf "$TMP_C"

# ---------------------------------------------------------------------------
# Case (d) — BOTH branch: both .yoke/prds/<slug>.md AND
#   .yoke/fixes/<slug>.md exist.
#   Asserts: exit non-zero, stdout empty, and stderr contains:
#     - the verbatim ratified header
#       "wm: ambiguous Phase-1 state for slug '<slug>'" (per AC-004-1
#       and the no-ambiguous-phase1 sensor's stable substring)
#     - both archive paths
#     - the "first 100 bytes:" excerpt fragment
#     - the "last commit:" line label
#     - a "git rm" example recipe
# Anchors AC-004-1.
# ---------------------------------------------------------------------------
TMP_D=$(mktemp -d)
D_OUT="$TMP_D/stdout"
D_ERR="$TMP_D/stderr"

set +e
(
  cd "$TMP_D"
  mkdir -p ".yoke/prds" ".yoke/fixes"
  printf '# stub PRD body\n> Status: approved\n' > ".yoke/prds/${VALID_SLUG}.md"
  printf '# stub fix-spec body\n> Status: approved\n' > ".yoke/fixes/${VALID_SLUG}.md"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "$VALID_SLUG"
) >"$D_OUT" 2>"$D_ERR"
D_RC=$?
set -e

D_STDOUT="$(cat "$D_OUT")"
D_STDERR="$(cat "$D_ERR")"

D_HEADER="wm: ambiguous Phase-1 state for slug '${VALID_SLUG}'"
if [[ "$D_RC" -ne 0 ]] \
  && [[ -z "$D_STDOUT" ]] \
  && [[ "$D_STDERR" == *"$D_HEADER"* ]] \
  && [[ "$D_STDERR" == *".yoke/prds/${VALID_SLUG}.md"* ]] \
  && [[ "$D_STDERR" == *".yoke/fixes/${VALID_SLUG}.md"* ]] \
  && [[ "$D_STDERR" == *"first 100 bytes:"* ]] \
  && [[ "$D_STDERR" == *"last commit:"* ]] \
  && [[ "$D_STDERR" == *"git rm"* ]]; then
  pass "(d) both: resolver aborts with verbatim 'wm: ambiguous Phase-1 state' diagnostic + paths + excerpts + commit + recipe"
else
  err "(d) both branch misbehaved rc=$D_RC stdout='$D_STDOUT' stderr=<<<$D_STDERR>>>"
fi

rm -rf "$TMP_D"

# ---------------------------------------------------------------------------
# Case (e) — read-vs-write symmetry: the resolver does NOT take a flag
#   distinguishing read or write callers. Calling it twice on the same
#   ambiguous state from two distinct contexts MUST yield the same exit
#   code and the same stderr structure (the diagnostic is byte-stable
#   modulo commit shas, which we do not constrain since the test runs
#   outside a git tree).
#
# Asserts: both invocations produce the same exit code AND the same
#          first line of stderr (the verbatim ratified header).
# Anchors PRD FR-9 "no read-vs-write split" + AC-004-1's "(read or write
# path)" wording.
# ---------------------------------------------------------------------------
TMP_E=$(mktemp -d)
E_ERR_1="$TMP_E/err1"
E_ERR_2="$TMP_E/err2"

set +e
(
  cd "$TMP_E"
  mkdir -p ".yoke/prds" ".yoke/fixes"
  printf '# stub PRD\n' > ".yoke/prds/${VALID_SLUG}.md"
  printf '# stub fix\n' > ".yoke/fixes/${VALID_SLUG}.md"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "$VALID_SLUG"
) >/dev/null 2>"$E_ERR_1"
E_RC_1=$?

(
  cd "$TMP_E"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  # Invoke a second time — same call site, no read-vs-write flag exists.
  wm_phase1_artifact_path "$VALID_SLUG"
) >/dev/null 2>"$E_ERR_2"
E_RC_2=$?
set -e

E_HEADER_1="$(head -n 1 "$E_ERR_1")"
E_HEADER_2="$(head -n 1 "$E_ERR_2")"
EXPECTED_HEADER="wm: ambiguous Phase-1 state for slug '${VALID_SLUG}'"

if [[ "$E_RC_1" -ne 0 && "$E_RC_2" -ne 0 ]] \
  && [[ "$E_RC_1" -eq "$E_RC_2" ]] \
  && [[ "$E_HEADER_1" == "$EXPECTED_HEADER" ]] \
  && [[ "$E_HEADER_2" == "$EXPECTED_HEADER" ]]; then
  pass "(e) read-vs-write symmetry: same rc + same diagnostic header on both invocations"
else
  err "(e) symmetry broke rc1=$E_RC_1 rc2=$E_RC_2 hdr1='$E_HEADER_1' hdr2='$E_HEADER_2' expected='$EXPECTED_HEADER'"
fi

rm -rf "$TMP_E"

# ---------------------------------------------------------------------------
# Case (f) — slug-validation negative branch: invalid slug → wm:-prefixed
#   stderr, non-zero exit, stdout empty. Resolver MUST validate the slug
#   at the boundary before any disk I/O.
# ---------------------------------------------------------------------------
TMP_F=$(mktemp -d)
F_OUT="$TMP_F/stdout"
F_ERR="$TMP_F/stderr"

set +e
(
  cd "$TMP_F"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "INVALID SLUG"
) >"$F_OUT" 2>"$F_ERR"
F_RC=$?
set -e

F_STDOUT="$(cat "$F_OUT")"
F_STDERR="$(cat "$F_ERR")"

if [[ "$F_RC" -ne 0 ]] && [[ "$F_STDERR" == wm:* ]] && [[ -z "$F_STDOUT" ]]; then
  pass "(f) slug-validation negative branch: invalid slug aborts non-zero with 'wm:'-prefixed stderr"
else
  err "(f) slug-validation branch misbehaved rc=$F_RC stdout='$F_STDOUT' stderr='$F_STDERR'"
fi

rm -rf "$TMP_F"

harness::summary
