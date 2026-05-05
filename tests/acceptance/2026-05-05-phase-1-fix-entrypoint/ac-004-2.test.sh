#!/usr/bin/env bash
# criterion: AC-004-2
#
# AC-004-2 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "When neither .yoke/prds/<slug>.md nor .yoke/fixes/<slug>.md
#    exists, the resolver emits a `wm:`-prefixed diagnostic ending
#    with the literal remediation hint
#    `Run /yoke:discover or /yoke:fix first.` and exits non-zero."
#
# Sprint scope (s02-t01): the helper `wm_phase1_artifact_path` must be
# present in `lib/working-memory/paths.sh` after this cycle. This test
# pins the "neither exists" branch verbatim — the literal remediation
# hint is the stable target downstream skill pre-flight error messages
# echo back to the user (per PRD Technical Considerations: every
# downstream skill's remediation hint updates from "Run /yoke:discover
# first." to "Run /yoke:discover or /yoke:fix first.").
#
# Observable conditions tested:
#   (1) `wm_phase1_artifact_path` symbol is exported by paths.sh
#       (pre-flight; missing helper short-circuits with unambiguous
#       evidence).
#   (2) When neither PRD nor fix-spec exists for <slug>, the resolver
#       exits non-zero.
#   (3) Stdout is empty on the abort path (no phantom path leaks).
#   (4) Stderr begins with the `wm:` prefix (matches the structured
#       diagnostic family).
#   (5) Stderr ends with the literal remediation hint
#       `Run /yoke:discover or /yoke:fix first.` (allowing only
#       trailing whitespace / newline).
#   (6) Stderr does NOT carry the AC-004-1 ambiguous-state substring
#       — the two abort branches MUST emit distinct diagnostics so
#       the no-ambiguous-phase1 sensor (s02-t05) does not false-positive
#       on a "neither" run.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
#   tests/acceptance/<slug>/ac-004-2.test.sh -> ../../..
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

PATHS_LIB="$REPO_ROOT/lib/working-memory/paths.sh"
if [[ ! -f "$PATHS_LIB" ]]; then
  err "missing paths.sh at $PATHS_LIB"
  harness::summary
fi

VALID_SLUG="2026-05-05-fix-axios-cve"
EXPECTED_REMEDIATION="Run /yoke:discover or /yoke:fix first."

# ---------------------------------------------------------------------------
# Case (1) — wm_phase1_artifact_path symbol is exported by paths.sh.
# ---------------------------------------------------------------------------
TMP_PRECHECK=$(mktemp -d)
set +e
(
  cd "$TMP_PRECHECK"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  declare -F wm_phase1_artifact_path >/dev/null
)
PRECHECK_RC=$?
set -e
rm -rf "$TMP_PRECHECK"

if [[ "$PRECHECK_RC" -eq 0 ]]; then
  pass "(1) wm_phase1_artifact_path is exported by lib/working-memory/paths.sh"
else
  err "(1) wm_phase1_artifact_path is NOT exported by lib/working-memory/paths.sh — declare -F returned $PRECHECK_RC"
  harness::summary
fi

# ---------------------------------------------------------------------------
# Build a tmpdir with NEITHER fixture present.
#
# The test creates the parent directory tree to rule out a defensive
# stat-on-parent failure path; only the slug-keyed files are absent.
# ---------------------------------------------------------------------------
TMP_NEITHER=$(mktemp -d)
T_OUT="$TMP_NEITHER/stdout"
T_ERR="$TMP_NEITHER/stderr"

mkdir -p "$TMP_NEITHER/.yoke/prds" "$TMP_NEITHER/.yoke/fixes"
# Sanity: assert both target paths really are absent.
if [[ -e "$TMP_NEITHER/.yoke/prds/${VALID_SLUG}.md" ]]; then
  err "fixture pre-condition broken: PRD path unexpectedly exists"
  harness::summary
fi
if [[ -e "$TMP_NEITHER/.yoke/fixes/${VALID_SLUG}.md" ]]; then
  err "fixture pre-condition broken: fix-spec path unexpectedly exists"
  harness::summary
fi

set +e
(
  cd "$TMP_NEITHER"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "$VALID_SLUG"
) >"$T_OUT" 2>"$T_ERR"
T_RC=$?
set -e

T_STDOUT="$(cat "$T_OUT")"
T_STDERR="$(cat "$T_ERR")"

# ---------------------------------------------------------------------------
# Case (2) — non-zero exit on the neither-exists branch.
# ---------------------------------------------------------------------------
if [[ "$T_RC" -ne 0 ]]; then
  pass "(2) wm_phase1_artifact_path '$VALID_SLUG' (neither file) aborts non-zero"
else
  err "(2) wm_phase1_artifact_path neither-file branch returned rc=0 (expected non-zero) stderr='$T_STDERR'"
fi

# ---------------------------------------------------------------------------
# Case (3) — stdout empty on the abort path.
# ---------------------------------------------------------------------------
if [[ -z "$T_STDOUT" ]]; then
  pass "(3) wm_phase1_artifact_path neither-file branch leaves stdout empty"
else
  err "(3) wm_phase1_artifact_path neither-file branch leaked to stdout: '$T_STDOUT'"
fi

# ---------------------------------------------------------------------------
# Case (4) — `wm:` prefix on stderr.
#
# Every paths.sh diagnostic starts with `wm:` (sensor pattern). The
# neither-exists branch is no exception.
# ---------------------------------------------------------------------------
if [[ "$T_STDERR" == wm:* ]]; then
  pass "(4) diagnostic begins with 'wm:' prefix"
else
  err "(4) diagnostic missing 'wm:' prefix — stderr-head='$(printf '%s' "$T_STDERR" | head -c 120)'"
fi

# ---------------------------------------------------------------------------
# Case (5) — diagnostic ends with the literal remediation hint.
#
# PRD FR-9 / AC-004-2: the diagnostic ENDS with
# "Run /yoke:discover or /yoke:fix first."
#
# We strip trailing whitespace + newlines and check the suffix.
# Substring presence alone is not enough — the AC mandates the hint
# is the closing element.
# ---------------------------------------------------------------------------
T5_STRIPPED="$(printf '%s' "$T_STDERR" | sed -e 's/[[:space:]]*$//')"
T5_TRIM_TRAIL_NL="${T5_STRIPPED%$'\n'}"

if [[ "$T5_TRIM_TRAIL_NL" == *"$EXPECTED_REMEDIATION" ]]; then
  pass "(5) diagnostic ends with literal remediation hint '$EXPECTED_REMEDIATION'"
else
  err "(5) diagnostic does NOT end with '$EXPECTED_REMEDIATION' — stderr-tail='$(printf '%s' "$T5_TRIM_TRAIL_NL" | tail -c 120)'"
fi

# ---------------------------------------------------------------------------
# Case (6) — neither-branch diagnostic does NOT carry the AC-004-1
# ambiguous-state substring.
#
# The two abort branches MUST emit distinct diagnostics. If the
# resolver collapsed them into a single message, the no-ambiguous-phase1
# sensor (s02-t05) would false-positive on every neither-exists run,
# poisoning CI. Pin the orthogonality.
# ---------------------------------------------------------------------------
AMBIGUOUS_SUBSTR="ambiguous Phase-1 state"
if grep -F -- "$AMBIGUOUS_SUBSTR" <<<"$T_STDERR" >/dev/null; then
  err "(6) neither-file branch incorrectly carries the AC-004-1 substring '$AMBIGUOUS_SUBSTR' — abort branches must emit distinct diagnostics"
else
  pass "(6) neither-file branch does NOT carry the AC-004-1 ambiguous-state substring (branches stay distinct)"
fi

rm -rf "$TMP_NEITHER"

harness::summary
