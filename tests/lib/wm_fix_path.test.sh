#!/usr/bin/env bash
# tests/lib/wm_fix_path.test.sh
#
# Happy-path + negative coverage for the new working-memory path helper
# added by the /yoke:fix Phase-1-entrypoint PRD (Sprint 01, Task t01):
#
#   wm_fix_path "<slug>"
#     Echoes ".yoke/fixes/<slug>.md" deterministically on a valid slug;
#     emits a "wm:"-prefixed slug-validation diagnostic to stderr and
#     returns non-zero on an invalid slug. Pure path computer — performs
#     NO filesystem I/O (no stat, no mkdir, no existence check).
#
# Anchors:
#   - PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-3)
#   - Spec: .yoke/specs/2026-05-05-phase-1-fix-entrypoint.md
#       ("APIs and Data Model :: wm_fix_path" entry)
#   - Acceptance Criteria (binding):
#       .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#       (US-003 DoD bullet "wm_fix_path ... exported from
#       lib/working-memory/paths.sh", AC-003-1)
#   - Sprint task: 2026-05-05-phase-1-fix-entrypoint-s01-t01
#
# The test sources `lib/working-memory/paths.sh` directly into a tmpdir
# CWD and exercises the helper without touching the host project's `.yoke/`.
# The "no I/O" property is asserted by running each happy-path call inside
# a tmpdir that contains NO `.yoke/` tree — if the helper attempted any
# stat/read/mkdir on the resolved path, behavior would diverge based on
# directory presence; by construction the helper returns the same path
# regardless of whether the file exists.
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

# Resolve repo root from the location of this file: tests/lib/wm_fix_path.test.sh -> ../..
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
KEBAB_SLUG="2026-05-05-phase-1-fix-entrypoint"
INVALID_SLUG_SPACE="INVALID SLUG"
INVALID_SLUG_UNDERSCORE="2026-01-01-foo_bar"
INVALID_SLUG_EMPTY=""

# ---------------------------------------------------------------------------
# Case (a) — wm_fix_path on a VALID slug
#   Asserts: stdout is exactly ".yoke/fixes/2026-01-01-foo.md",
#            stderr is empty, exit code is 0. CWD is a tmpdir with NO
#            .yoke/ tree, proving the helper does not depend on disk state.
# Anchors AC-003-1.
# ---------------------------------------------------------------------------
TMP_A=$(mktemp -d)
A_OUT="$TMP_A/stdout"
A_ERR="$TMP_A/stderr"

set +e
(
  cd "$TMP_A"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$VALID_SLUG"
) >"$A_OUT" 2>"$A_ERR"
A_RC=$?
set -e

EXPECTED_PATH=".yoke/fixes/${VALID_SLUG}.md"
A_STDOUT="$(cat "$A_OUT")"
A_STDERR="$(cat "$A_ERR")"

if [[ "$A_RC" -eq 0 && "$A_STDOUT" == "$EXPECTED_PATH" && -z "$A_STDERR" ]]; then
  pass "(a) wm_fix_path '$VALID_SLUG' -> '$EXPECTED_PATH' (rc=0, stderr empty)"
else
  err "(a) wm_fix_path mismatch rc=$A_RC stdout='$A_STDOUT' stderr='$A_STDERR' expected='$EXPECTED_PATH'"
fi

rm -rf "$TMP_A"

# ---------------------------------------------------------------------------
# Case (b) — wm_fix_path on a kebab-multi-word VALID slug
#   Asserts: full kebab-cased filename survives unchanged in the output
#            (kebab-only output, no normalization or rewriting). Anchors
#            the PRD FR-4 slug-regex acceptance contract — slug regex
#            permits multi-segment kebab slugs up to 50 chars after the
#            date prefix.
# ---------------------------------------------------------------------------
TMP_B=$(mktemp -d)
B_OUT="$TMP_B/stdout"
B_ERR="$TMP_B/stderr"

set +e
(
  cd "$TMP_B"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$KEBAB_SLUG"
) >"$B_OUT" 2>"$B_ERR"
B_RC=$?
set -e

EXPECTED_KEBAB=".yoke/fixes/${KEBAB_SLUG}.md"
B_STDOUT="$(cat "$B_OUT")"
B_STDERR="$(cat "$B_ERR")"

if [[ "$B_RC" -eq 0 && "$B_STDOUT" == "$EXPECTED_KEBAB" && -z "$B_STDERR" ]]; then
  pass "(b) wm_fix_path '$KEBAB_SLUG' -> '$EXPECTED_KEBAB' (kebab passthrough)"
else
  err "(b) wm_fix_path kebab mismatch rc=$B_RC stdout='$B_STDOUT' stderr='$B_STDERR' expected='$EXPECTED_KEBAB'"
fi

rm -rf "$TMP_B"

# ---------------------------------------------------------------------------
# Case (c) — wm_fix_path on an INVALID slug (whitespace)
#   Asserts: exit code is non-zero AND stderr starts with `wm:` (the
#            documented slug-validation diagnostic prefix in paths.sh).
# Negative-branch coverage for the slug-regex acceptance contract.
# ---------------------------------------------------------------------------
TMP_C=$(mktemp -d)
C_OUT="$TMP_C/stdout"
C_ERR="$TMP_C/stderr"

set +e
(
  cd "$TMP_C"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$INVALID_SLUG_SPACE"
) >"$C_OUT" 2>"$C_ERR"
C_RC=$?
set -e

C_STDOUT="$(cat "$C_OUT")"
C_STDERR="$(cat "$C_ERR")"

if [[ "$C_RC" -ne 0 ]] && [[ "$C_STDERR" == wm:* ]] && [[ -z "$C_STDOUT" ]]; then
  pass "(c) wm_fix_path '$INVALID_SLUG_SPACE' aborts non-zero with 'wm:'-prefixed stderr"
else
  err "(c) wm_fix_path negative branch (whitespace) misbehaved rc=$C_RC stdout='$C_STDOUT' stderr='$C_STDERR'"
fi

rm -rf "$TMP_C"

# ---------------------------------------------------------------------------
# Case (d) — wm_fix_path on an INVALID slug (underscore — slug regex
#   forbids `_`; permits only kebab-lowercase-alnum after the date prefix)
#   Asserts: exit code is non-zero AND stderr starts with `wm:`.
# Anchors the slug-regex acceptance contract.
# ---------------------------------------------------------------------------
TMP_D=$(mktemp -d)
D_OUT="$TMP_D/stdout"
D_ERR="$TMP_D/stderr"

set +e
(
  cd "$TMP_D"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$INVALID_SLUG_UNDERSCORE"
) >"$D_OUT" 2>"$D_ERR"
D_RC=$?
set -e

D_STDOUT="$(cat "$D_OUT")"
D_STDERR="$(cat "$D_ERR")"

if [[ "$D_RC" -ne 0 ]] && [[ "$D_STDERR" == wm:* ]] && [[ -z "$D_STDOUT" ]]; then
  pass "(d) wm_fix_path '$INVALID_SLUG_UNDERSCORE' aborts non-zero with 'wm:'-prefixed stderr"
else
  err "(d) wm_fix_path negative branch (underscore) misbehaved rc=$D_RC stdout='$D_STDOUT' stderr='$D_STDERR'"
fi

rm -rf "$TMP_D"

# ---------------------------------------------------------------------------
# Case (e) — wm_fix_path on EMPTY argument with NO active slug
#   Asserts: exit code is non-zero AND stderr starts with `wm:` (the
#            "no active task" diagnostic from wm_active_slug). The empty
#            argument falls back to wm_active_slug, which fails when
#            .yoke/runtime/.current is absent.
# ---------------------------------------------------------------------------
TMP_E=$(mktemp -d)
E_OUT="$TMP_E/stdout"
E_ERR="$TMP_E/stderr"

set +e
(
  cd "$TMP_E"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$INVALID_SLUG_EMPTY"
) >"$E_OUT" 2>"$E_ERR"
E_RC=$?
set -e

E_STDOUT="$(cat "$E_OUT")"
E_STDERR="$(cat "$E_ERR")"

if [[ "$E_RC" -ne 0 ]] && [[ "$E_STDERR" == wm:* ]] && [[ -z "$E_STDOUT" ]]; then
  pass "(e) wm_fix_path with empty arg + no .current aborts with 'wm:'-prefixed stderr"
else
  err "(e) wm_fix_path empty-arg branch misbehaved rc=$E_RC stdout='$E_STDOUT' stderr='$E_STDERR'"
fi

rm -rf "$TMP_E"

# ---------------------------------------------------------------------------
# Case (f) — "no I/O" property — output is identical regardless of whether
#   the resolved file exists on disk. The helper is a pure path computer
#   per the FR-3 contract; this test asserts the property by computing the
#   path twice in the same tmpdir CWD: once with no file present, once
#   with the file materialized. Both invocations MUST produce the same
#   stdout, prove the helper does not switch on disk state.
# Anchors AC-003-1's "as a string regardless of whether the file exists".
# ---------------------------------------------------------------------------
TMP_F=$(mktemp -d)
F_OUT_BEFORE="$TMP_F/before"
F_OUT_AFTER="$TMP_F/after"

set +e
(
  cd "$TMP_F"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_fix_path "$VALID_SLUG"
) >"$F_OUT_BEFORE" 2>/dev/null
F1_RC=$?

# Materialize the resolved path so the file now exists.
(
  cd "$TMP_F"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  resolved="$(wm_fix_path "$VALID_SLUG")"
  mkdir -p "$(dirname "$resolved")"
  printf '# stub fix-spec\n' > "$resolved"
  wm_fix_path "$VALID_SLUG"
) >"$F_OUT_AFTER" 2>/dev/null
F2_RC=$?
set -e

F_BEFORE="$(cat "$F_OUT_BEFORE")"
F_AFTER="$(cat "$F_OUT_AFTER")"

if [[ "$F1_RC" -eq 0 && "$F2_RC" -eq 0 && "$F_BEFORE" == "$F_AFTER" && "$F_BEFORE" == ".yoke/fixes/${VALID_SLUG}.md" ]]; then
  pass "(f) wm_fix_path output identical with file absent and present (pure path computer)"
else
  err "(f) wm_fix_path output diverged on disk state: before='$F_BEFORE' (rc=$F1_RC) after='$F_AFTER' (rc=$F2_RC)"
fi

rm -rf "$TMP_F"

harness::summary
