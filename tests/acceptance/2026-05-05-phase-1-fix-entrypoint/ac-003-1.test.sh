#!/usr/bin/env bash
# criterion: AC-003-1
#
# AC-003-1 (sprint-01 narrowing per
# .yoke/sprints/2026-05-05-phase-1-fix-entrypoint-s01.md task t01):
#
#   "existing PRD-backed flow continues working post-helper addition;
#    new helper resolves to .yoke/fixes/<slug>.md as a string regardless
#    of whether the file exists."
#
# Binding contract:
#   .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#   (US-003 DoD bullet 1: "wm_fix_path and wm_phase1_artifact_path
#    exported from lib/working-memory/paths.sh")
#
# Sprint scope (s01-t01): only `wm_fix_path` is in play this cycle.
# `wm_phase1_artifact_path` is a later sprint; this test does NOT
# assert its existence.
#
# Sr Eng's surface for this cycle is `lib/working-memory/paths.sh`. The
# helper `wm_fix_path "<slug>"` MUST:
#
#   (a) resolve to `.yoke/fixes/<slug>.md` as a string for any valid
#       slug, regardless of whether the file exists on disk (pure path
#       computer, no I/O);
#   (b) emit a `wm:`-prefixed slug-validation diagnostic to stderr and
#       exit non-zero on an invalid slug, mirroring the existing
#       `wm_prd_path` / `wm_spec_path` / `wm_acceptance_criteria_path`
#       error contract;
#   (c) NOT regress any existing path helper — the file's other
#       symbols (`wm_prd_path`, `wm_spec_path`,
#       `wm_acceptance_criteria_path`) must keep their pre-cutover
#       behaviour bit-for-bit on a valid slug.
#
# Pure-path means: no `[ -f ]`, no `stat`, no `cat`, no `test -e`, no
# `ls` inside the helper body. The test pins this by inspecting the
# function source via `declare -f` and by asserting the helper returns
# the same path whether the file exists or not.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
#   tests/acceptance/<slug>/ac-003-1.test.sh -> ../../..
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
INVALID_SLUG="INVALID SLUG"
EXPECTED_PATH=".yoke/fixes/${VALID_SLUG}.md"

# ---------------------------------------------------------------------------
# Case (1) — wm_fix_path symbol is exported by paths.sh.
#
# A pre-flight: a missing helper short-circuits every other case with a
# clear diagnostic so Sr Eng's réplica has unambiguous evidence.
# ---------------------------------------------------------------------------
TMP_PRECHECK=$(mktemp -d)
set +e
(
  cd "$TMP_PRECHECK"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  declare -F wm_fix_path >/dev/null
)
PRECHECK_RC=$?
set -e
rm -rf "$TMP_PRECHECK"

if [[ "$PRECHECK_RC" -eq 0 ]]; then
  pass "(1) wm_fix_path is exported by lib/working-memory/paths.sh"
else
  err "(1) wm_fix_path is NOT exported by lib/working-memory/paths.sh — declare -F returned $PRECHECK_RC"
  # Hard-stop: every downstream assertion presupposes the helper exists.
  harness::summary
fi

# ---------------------------------------------------------------------------
# Case (2) — wm_fix_path on a VALID slug, file ABSENT on disk.
#
#   stdout MUST be exactly `.yoke/fixes/<valid-slug>.md`,
#   stderr MUST be empty,
#   exit code MUST be 0.
#
# Pins the "regardless of whether the file exists" half of AC-003-1.
# ---------------------------------------------------------------------------
TMP_2=$(mktemp -d)
T2_OUT="$TMP_2/stdout"
T2_ERR="$TMP_2/stderr"

set +e
(
  cd "$TMP_2"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$VALID_SLUG"
) >"$T2_OUT" 2>"$T2_ERR"
T2_RC=$?
set -e

T2_STDOUT="$(cat "$T2_OUT")"
T2_STDERR="$(cat "$T2_ERR")"

if [[ "$T2_RC" -eq 0 && "$T2_STDOUT" == "$EXPECTED_PATH" && -z "$T2_STDERR" ]]; then
  pass "(2) wm_fix_path '$VALID_SLUG' (file absent) -> '$EXPECTED_PATH' (rc=0, stderr empty)"
else
  err "(2) wm_fix_path absent-file mismatch rc=$T2_RC stdout='$T2_STDOUT' stderr='$T2_STDERR' expected='$EXPECTED_PATH'"
fi

rm -rf "$TMP_2"

# ---------------------------------------------------------------------------
# Case (3) — wm_fix_path on a VALID slug, file PRESENT on disk.
#
# Same observable output as Case (2). The helper must be a pure path
# computer; presence/absence of the target file MUST NOT change the
# returned string, the exit code, or stderr. Pins the "as a string" half
# of AC-003-1 and forecloses any future drift toward an existence-aware
# branch (which is reserved exclusively for `wm_phase1_artifact_path`
# per PRD FR-9 / Spec Architecture invariant).
# ---------------------------------------------------------------------------
TMP_3=$(mktemp -d)
T3_OUT="$TMP_3/stdout"
T3_ERR="$TMP_3/stderr"

# Materialize the target file inside the tmpdir so the helper would,
# if it were existence-aware, observe it and (incorrectly) branch.
mkdir -p "$TMP_3/.yoke/fixes"
printf '# stub fix-spec\n' > "$TMP_3/.yoke/fixes/${VALID_SLUG}.md"

set +e
(
  cd "$TMP_3"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$VALID_SLUG"
) >"$T3_OUT" 2>"$T3_ERR"
T3_RC=$?
set -e

T3_STDOUT="$(cat "$T3_OUT")"
T3_STDERR="$(cat "$T3_ERR")"

if [[ "$T3_RC" -eq 0 && "$T3_STDOUT" == "$EXPECTED_PATH" && -z "$T3_STDERR" ]]; then
  pass "(3) wm_fix_path '$VALID_SLUG' (file present) -> '$EXPECTED_PATH' (rc=0, stderr empty)"
else
  err "(3) wm_fix_path present-file mismatch rc=$T3_RC stdout='$T3_STDOUT' stderr='$T3_STDERR' expected='$EXPECTED_PATH'"
fi

rm -rf "$TMP_3"

# ---------------------------------------------------------------------------
# Case (4) — wm_fix_path on an INVALID slug.
#
#   exit code MUST be non-zero,
#   stderr MUST start with the literal `wm:` prefix (the documented
#     slug-validation diagnostic shape in paths.sh),
#   stdout MUST be empty.
#
# Pins the slug-validation contract — `wm_fix_path` MUST delegate to
# `wm_validate_slug` exactly like its peers.
# ---------------------------------------------------------------------------
TMP_4=$(mktemp -d)
T4_OUT="$TMP_4/stdout"
T4_ERR="$TMP_4/stderr"

set +e
(
  cd "$TMP_4"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$INVALID_SLUG"
) >"$T4_OUT" 2>"$T4_ERR"
T4_RC=$?
set -e

T4_STDOUT="$(cat "$T4_OUT")"
T4_STDERR="$(cat "$T4_ERR")"

if [[ "$T4_RC" -ne 0 ]] && [[ "$T4_STDERR" == wm:* ]] && [[ -z "$T4_STDOUT" ]]; then
  pass "(4) wm_fix_path '$INVALID_SLUG' aborts non-zero with 'wm:'-prefixed stderr (stdout empty)"
else
  err "(4) wm_fix_path invalid-slug branch misbehaved rc=$T4_RC stdout='$T4_STDOUT' stderr='$T4_STDERR'"
fi

rm -rf "$TMP_4"

# ---------------------------------------------------------------------------
# Case (5) — wm_fix_path body contains no I/O syscalls.
#
# Inspect the function source via `declare -f` and assert that none of
# the I/O verbs documented as forbidden for pure path computers appear
# in the body. The list is not exhaustive (a malicious helper could
# call out to `awk`/`python` to do I/O) but it pins the obvious
# mistakes and gives Sr QA's réplica a concrete location to cite.
# ---------------------------------------------------------------------------
TMP_5=$(mktemp -d)
T5_BODY="$TMP_5/body"

set +e
(
  cd "$TMP_5"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  declare -f wm_fix_path
) >"$T5_BODY" 2>/dev/null
T5_RC=$?
set -e

# Forbidden I/O tokens. We grep with word boundaries where bash allows
# (using `[[:space:]]` neighbours) so substrings inside identifiers are
# not flagged. The intent is to catch obvious filesystem reads added
# inside the helper body.
T5_BODY_TEXT="$(cat "$T5_BODY")"
T5_VIOLATIONS=()

# `[ -f ...]` / `[[ -f ...]]` / `[ -e ...]` / `[[ -e ...]]`
if grep -E '\[\[?[[:space:]]+-[fed][[:space:]]' <<<"$T5_BODY_TEXT" >/dev/null; then
  T5_VIOLATIONS+=("filesystem test operator (-f / -e / -d) found in body")
fi
# `stat` as a standalone command call.
if grep -E '(^|[[:space:];|&])stat[[:space:]]' <<<"$T5_BODY_TEXT" >/dev/null; then
  T5_VIOLATIONS+=("'stat' invocation found in body")
fi
# `cat <something>` (rules out `cat <<EOF` heredocs by requiring a
# non-`<` next byte after the space).
if grep -E '(^|[[:space:];|&])cat[[:space:]]+[^<]' <<<"$T5_BODY_TEXT" >/dev/null; then
  T5_VIOLATIONS+=("'cat' invocation found in body")
fi
# `ls` invocation.
if grep -E '(^|[[:space:];|&])ls[[:space:]]' <<<"$T5_BODY_TEXT" >/dev/null; then
  T5_VIOLATIONS+=("'ls' invocation found in body")
fi
# `find` invocation.
if grep -E '(^|[[:space:];|&])find[[:space:]]' <<<"$T5_BODY_TEXT" >/dev/null; then
  T5_VIOLATIONS+=("'find' invocation found in body")
fi

if [[ "$T5_RC" -eq 0 && "${#T5_VIOLATIONS[@]}" -eq 0 ]]; then
  pass "(5) wm_fix_path body is pure path computation (no obvious I/O syscalls)"
else
  err "(5) wm_fix_path body contains I/O syscalls: ${T5_VIOLATIONS[*]:-<could-not-read-body rc=$T5_RC>}"
fi

rm -rf "$TMP_5"

# ---------------------------------------------------------------------------
# Case (6) — non-regression for existing path helpers.
#
# AC-003-1's "existing PRD-backed flow continues working post-helper
# addition" is the no-regression half of the criterion. The minimum
# pin is that the three pre-existing helpers (`wm_prd_path`,
# `wm_spec_path`, `wm_acceptance_criteria_path`) still echo their
# documented strings on a valid slug and emit a `wm:`-prefixed
# diagnostic on an invalid slug. Anything broader is covered by the
# repo's existing wm-paths.test.sh and working-memory.test.sh suites,
# which run in the same CI lane.
# ---------------------------------------------------------------------------
TMP_6=$(mktemp -d)
T6_RC=0

declare -A T6_EXPECTED=(
  ["wm_prd_path"]=".yoke/prds/${VALID_SLUG}.md"
  ["wm_spec_path"]=".yoke/specs/${VALID_SLUG}.md"
  ["wm_acceptance_criteria_path"]=".yoke/acceptance-criteria/${VALID_SLUG}.md"
)

T6_REGRESSIONS=()

for helper in "${!T6_EXPECTED[@]}"; do
  expected="${T6_EXPECTED[$helper]}"
  out_file="$TMP_6/$helper.out"
  err_file="$TMP_6/$helper.err"

  set +e
  (
    cd "$TMP_6"
    # shellcheck source=/dev/null
    source "$PATHS_LIB"
    "$helper" "$VALID_SLUG"
  ) >"$out_file" 2>"$err_file"
  rc=$?
  set -e

  out_val="$(cat "$out_file")"
  err_val="$(cat "$err_file")"

  if [[ "$rc" -ne 0 || "$out_val" != "$expected" || -n "$err_val" ]]; then
    T6_REGRESSIONS+=("$helper rc=$rc stdout='$out_val' stderr='$err_val' expected='$expected'")
  fi
done

if [[ "${#T6_REGRESSIONS[@]}" -eq 0 ]]; then
  pass "(6) pre-existing helpers (wm_prd_path / wm_spec_path / wm_acceptance_criteria_path) unchanged on '$VALID_SLUG'"
else
  for line in "${T6_REGRESSIONS[@]}"; do
    err "(6) pre-existing helper regressed: $line"
  done
fi

rm -rf "$TMP_6"

harness::summary
