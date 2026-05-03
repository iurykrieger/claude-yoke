#!/usr/bin/env bash
# tests/wm-paths.test.sh
#
# Happy-path + negative coverage for the post-rename working-memory path
# helpers added by the generate-sprints PRD (US-002 DoD):
#
#   wm_acceptance_criteria_path "<slug>"
#     Echoes ".yoke/acceptance-criteria/<slug>.md" on a valid slug; emits
#     a "wm:"-prefixed slug-validation diagnostic to stderr and returns
#     non-zero on an invalid slug.
#
#   wm_acceptance_criteria_in_use "<slug>"
#     Returns 0 when the file at the resolved path exists, 1 otherwise.
#     The predicate mirrors `wm_slug_in_use`'s shape, scoped to the AC
#     archive only.
#
# Anchors:
#   - PRD: .yoke/prds/2026-05-03-generate-sprints-skill.md
#   - Acceptance Criteria (binding): .yoke/acceptance-criteria/2026-05-03-generate-sprints-skill.md
#       (US-002 DoD bullet `tests/wm-paths.test.sh covers the new helpers`,
#        AC-002-1 / AC-002-2 / AC-002-3)
#   - Sprint contract: .yoke/sprints/2026-05-03-generate-sprints-skill-s01.md (s01-t02)
#
# The test sources `lib/working-memory/paths.sh` directly into a tmpdir
# and exercises the helpers without touching the host project's `.yoke/`.
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

# Resolve repo root from the location of this file: tests/wm-paths.test.sh -> ..
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Source the harness for pass/err/summary helpers.
source "$REPO_ROOT/tests/lib/harness.sh"

PATHS_LIB="$REPO_ROOT/lib/working-memory/paths.sh"
if [[ ! -f "$PATHS_LIB" ]]; then
  err "missing paths.sh at $PATHS_LIB"
  harness::summary
fi

VALID_SLUG="2026-01-01-foo"
INVALID_SLUG="INVALID SLUG"

# ---------------------------------------------------------------------------
# Case (a) — wm_acceptance_criteria_path on a VALID slug
#   Asserts: stdout is exactly ".yoke/acceptance-criteria/2026-01-01-foo.md",
#            stderr is empty, exit code is 0.
# Anchors AC-002-1.
# ---------------------------------------------------------------------------
TMP_A=$(mktemp -d)
A_OUT="$TMP_A/stdout"
A_ERR="$TMP_A/stderr"

set +e
(
  cd "$TMP_A"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_acceptance_criteria_path "$VALID_SLUG"
) >"$A_OUT" 2>"$A_ERR"
A_RC=$?
set -e

EXPECTED_PATH=".yoke/acceptance-criteria/${VALID_SLUG}.md"
A_STDOUT="$(cat "$A_OUT")"
A_STDERR="$(cat "$A_ERR")"

if [[ "$A_RC" -eq 0 && "$A_STDOUT" == "$EXPECTED_PATH" && -z "$A_STDERR" ]]; then
  pass "(a) wm_acceptance_criteria_path '$VALID_SLUG' -> '$EXPECTED_PATH' (rc=0)"
else
  err "(a) wm_acceptance_criteria_path mismatch rc=$A_RC stdout='$A_STDOUT' stderr='$A_STDERR' expected='$EXPECTED_PATH'"
fi

rm -rf "$TMP_A"

# ---------------------------------------------------------------------------
# Case (b) — wm_acceptance_criteria_path on an INVALID slug
#   Asserts: exit code is non-zero AND stderr starts with `wm:` (the
#            documented slug-validation diagnostic prefix in paths.sh).
# Negative-branch coverage for AC-002-1.
# ---------------------------------------------------------------------------
TMP_B=$(mktemp -d)
B_OUT="$TMP_B/stdout"
B_ERR="$TMP_B/stderr"

set +e
(
  cd "$TMP_B"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_acceptance_criteria_path "$INVALID_SLUG"
) >"$B_OUT" 2>"$B_ERR"
B_RC=$?
set -e

B_STDOUT="$(cat "$B_OUT")"
B_STDERR="$(cat "$B_ERR")"

if [[ "$B_RC" -ne 0 ]] && [[ "$B_STDERR" == wm:* ]] && [[ -z "$B_STDOUT" ]]; then
  pass "(b) wm_acceptance_criteria_path '$INVALID_SLUG' aborts non-zero with 'wm:'-prefixed stderr"
else
  err "(b) wm_acceptance_criteria_path negative branch misbehaved rc=$B_RC stdout='$B_STDOUT' stderr='$B_STDERR'"
fi

rm -rf "$TMP_B"

# ---------------------------------------------------------------------------
# Case (c) — wm_acceptance_criteria_in_use predicate
#   Sub-case (c1): file exists  -> exit 0
#   Sub-case (c2): file absent  -> exit 1
# Uses a tmpdir as the working CWD so that the relative path
# `.yoke/acceptance-criteria/<slug>.md` resolves under the tmpdir, not
# the host project. Anchors AC-002-2.
# ---------------------------------------------------------------------------
TMP_C=$(mktemp -d)

# (c1) file exists -> exit 0
set +e
(
  cd "$TMP_C"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  ac_path="$(wm_acceptance_criteria_path "$VALID_SLUG")"
  mkdir -p "$(dirname "$ac_path")"
  printf '# stub\n' > "$ac_path"
  wm_acceptance_criteria_in_use "$VALID_SLUG"
)
C1_RC=$?
set -e

if [[ "$C1_RC" -eq 0 ]]; then
  pass "(c1) wm_acceptance_criteria_in_use returns 0 when AC file exists"
else
  err "(c1) wm_acceptance_criteria_in_use should return 0 when AC file exists; got rc=$C1_RC"
fi

# (c2) file absent -> exit 1
TMP_C2=$(mktemp -d)
set +e
(
  cd "$TMP_C2"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_acceptance_criteria_in_use "$VALID_SLUG"
)
C2_RC=$?
set -e

if [[ "$C2_RC" -eq 1 ]]; then
  pass "(c2) wm_acceptance_criteria_in_use returns 1 when AC file is absent"
else
  err "(c2) wm_acceptance_criteria_in_use should return 1 when AC file is absent; got rc=$C2_RC"
fi

rm -rf "$TMP_C" "$TMP_C2"

harness::summary
