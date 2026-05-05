#!/usr/bin/env bash
# criterion: AC-004-1
#
# AC-004-1 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "When both .yoke/prds/<slug>.md and .yoke/fixes/<slug>.md exist on
#    disk for slug <slug>, invoking any caller of
#    wm_phase1_artifact_path (read or write path) emits to stderr a
#    message starting exactly with `wm: ambiguous Phase-1 state for
#    slug '<slug>'` and exits non-zero. The full diagnostic includes
#    both paths, first-100 bytes of each file body, last commit sha +
#    author + ISO-8601 timestamp for each file, and a `git rm` example
#    recipe."
#
# Sprint scope (s02-t01): the helper `wm_phase1_artifact_path` must be
# present in `lib/working-memory/paths.sh` after this cycle. This test
# pins the "both exist" branch verbatim — the substring check is the
# stable hook the no-ambiguous-phase1 sensor (s02-t05) depends on per
# AC-004-4.
#
# Observable conditions tested:
#   (1) `wm_phase1_artifact_path` symbol is exported by paths.sh
#       (pre-flight; missing helper short-circuits with unambiguous
#       evidence so Sr Eng's réplica has a concrete location).
#   (2) When both PRD and fix-spec exist for <slug>, the resolver
#       exits non-zero and stderr begins exactly with
#       `wm: ambiguous Phase-1 state for slug '<slug>'`.
#   (3) Stdout is empty on the abort path (no phantom path leaks to
#       a downstream caller that wired stdout into a variable).
#   (4) The diagnostic carries both archive paths verbatim
#       (`.yoke/prds/<slug>.md` and `.yoke/fixes/<slug>.md`).
#   (5) The diagnostic carries a `git rm` recipe (the recovery
#       instruction half of the structured-sensor-output contract).
#   (6) The diagnostic carries a first-100-bytes excerpt for each file
#       — the test uses unique markers in each fixture body and asserts
#       both markers appear in stderr.
#   (7) The diagnostic carries a last-commit reference for each file
#       (sha + author + iso-8601 timestamp). Outside a real git repo
#       the resolver SHOULD still produce a structured diagnostic; this
#       case asserts the substring `last commit` appears (verbatim
#       label from PRD FR-9). When the directory is a git repo the
#       sha/author/timestamp MUST resolve; outside, a graceful
#       placeholder is acceptable as long as the label is present.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
#   tests/acceptance/<slug>/ac-004-1.test.sh -> ../../..
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
EXPECTED_PRD_PATH=".yoke/prds/${VALID_SLUG}.md"
EXPECTED_FIX_PATH=".yoke/fixes/${VALID_SLUG}.md"

# Sentinel substrings injected into each fixture so we can assert that
# the diagnostic excerpts the body of each file (not just the path).
PRD_MARKER="PRD-MARKER-9F2A1C"
FIX_MARKER="FIX-MARKER-7B4D8E"

# ---------------------------------------------------------------------------
# Case (1) — wm_phase1_artifact_path symbol is exported by paths.sh.
#
# Pre-flight: a missing helper short-circuits every other case with a
# clear diagnostic so Sr Eng's réplica has unambiguous evidence.
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
  # Hard-stop: every downstream assertion presupposes the helper exists.
  harness::summary
fi

# ---------------------------------------------------------------------------
# Build a tmpdir initialised as a real git repo carrying both fixtures.
#
# Real git history matters: PRD FR-9's diagnostic includes "last commit
# sha + author + ISO-8601 timestamp", which the resolver must read via
# git plumbing. A tmpdir without git history would let a buggy resolver
# emit empty fields and still satisfy a substring-only assertion. The
# test commits both fixtures so the diagnostic has real metadata to
# carry.
# ---------------------------------------------------------------------------
TMP_BOTH=$(mktemp -d)
T_OUT="$TMP_BOTH/stdout"
T_ERR="$TMP_BOTH/stderr"

mkdir -p "$TMP_BOTH/.yoke/prds" "$TMP_BOTH/.yoke/fixes"
printf '# PRD body — %s\n\nIntroduction.\n' "$PRD_MARKER" \
  > "$TMP_BOTH/.yoke/prds/${VALID_SLUG}.md"
printf '# Fix-spec body — %s\n\nWhat broke.\n' "$FIX_MARKER" \
  > "$TMP_BOTH/.yoke/fixes/${VALID_SLUG}.md"

(
  cd "$TMP_BOTH"
  git init -q
  git config user.email "ac-004-1@yoke.test"
  git config user.name "AC-004-1 Fixture"
  git add .yoke/prds/"${VALID_SLUG}.md" .yoke/fixes/"${VALID_SLUG}.md"
  git commit -q -m "fixture: both Phase-1 archives for ${VALID_SLUG}"
) >/dev/null

set +e
(
  cd "$TMP_BOTH"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "$VALID_SLUG"
) >"$T_OUT" 2>"$T_ERR"
T_RC=$?
set -e

T_STDOUT="$(cat "$T_OUT")"
T_STDERR="$(cat "$T_ERR")"

# ---------------------------------------------------------------------------
# Case (2) — non-zero exit + verbatim "wm: ambiguous Phase-1 state for
# slug '<slug>'" prefix on stderr.
#
# The leading substring is the stable target the AC-004-4 CI gate
# (no-ambiguous-phase1 sensor, sprint task t05) depends on. Pin the
# exact byte sequence — any drift here breaks the sensor.
# ---------------------------------------------------------------------------
EXPECTED_PREFIX="wm: ambiguous Phase-1 state for slug '${VALID_SLUG}'"

if [[ "$T_RC" -ne 0 ]] && [[ "$T_STDERR" == "$EXPECTED_PREFIX"* ]]; then
  pass "(2) wm_phase1_artifact_path '$VALID_SLUG' (both files) aborts non-zero with stderr starting '$EXPECTED_PREFIX'"
else
  err "(2) wm_phase1_artifact_path both-exist branch misbehaved rc=$T_RC stderr-head='$(printf '%s' "$T_STDERR" | head -c 200)' expected-prefix='$EXPECTED_PREFIX'"
fi

# ---------------------------------------------------------------------------
# Case (3) — stdout is empty on the abort path.
#
# A downstream caller that wired stdout into a variable
# (e.g. `path="$(wm_phase1_artifact_path "$slug")"`) MUST NOT receive
# a phantom path on the abort branch. Empty stdout pins this.
# ---------------------------------------------------------------------------
if [[ -z "$T_STDOUT" ]]; then
  pass "(3) wm_phase1_artifact_path both-exist branch leaves stdout empty (no phantom path)"
else
  err "(3) wm_phase1_artifact_path both-exist branch leaked to stdout: '$T_STDOUT'"
fi

# ---------------------------------------------------------------------------
# Case (4) — both archive paths appear in the diagnostic.
#
# PRD FR-9 mandates the structured recovery diagnostic carry both
# `.yoke/prds/<slug>.md` and `.yoke/fixes/<slug>.md`. Without both
# paths the user cannot run the `git rm` recipe — the diagnostic must
# tell the user where each file lives.
# ---------------------------------------------------------------------------
T4_MISSING=()
if ! grep -F -- "$EXPECTED_PRD_PATH" <<<"$T_STDERR" >/dev/null; then
  T4_MISSING+=("$EXPECTED_PRD_PATH")
fi
if ! grep -F -- "$EXPECTED_FIX_PATH" <<<"$T_STDERR" >/dev/null; then
  T4_MISSING+=("$EXPECTED_FIX_PATH")
fi

if [[ "${#T4_MISSING[@]}" -eq 0 ]]; then
  pass "(4) diagnostic carries both archive paths verbatim ('$EXPECTED_PRD_PATH', '$EXPECTED_FIX_PATH')"
else
  err "(4) diagnostic missing path(s): ${T4_MISSING[*]}"
fi

# ---------------------------------------------------------------------------
# Case (5) — `git rm` recipe appears in the diagnostic.
#
# PRD FR-9's verbatim text includes the recipe shape:
#   git rm .yoke/<dir>/<slug>.md && git commit
# Pin the substring `git rm` so a Sr Eng implementation that drops the
# recipe (or rewrites it as a comment) trips the test.
# ---------------------------------------------------------------------------
if grep -F -- "git rm" <<<"$T_STDERR" >/dev/null; then
  pass "(5) diagnostic carries 'git rm' recovery recipe"
else
  err "(5) diagnostic missing 'git rm' recovery recipe (stderr-head='$(printf '%s' "$T_STDERR" | head -c 200)')"
fi

# ---------------------------------------------------------------------------
# Case (6) — first-100-bytes excerpt of each file body appears in the
# diagnostic.
#
# Each fixture carries a unique sentinel marker in its body. Asserting
# both markers reach stderr proves the resolver actually reads the
# files and excerpts their content (rather than emitting a stub
# placeholder). The PRD FR-9 contract reads "first 100 bytes" — the
# markers are inside the first 100 bytes by construction, so a correct
# implementation MUST surface both.
# ---------------------------------------------------------------------------
T6_MISSING=()
if ! grep -F -- "$PRD_MARKER" <<<"$T_STDERR" >/dev/null; then
  T6_MISSING+=("$PRD_MARKER (PRD body excerpt)")
fi
if ! grep -F -- "$FIX_MARKER" <<<"$T_STDERR" >/dev/null; then
  T6_MISSING+=("$FIX_MARKER (fix-spec body excerpt)")
fi

if [[ "${#T6_MISSING[@]}" -eq 0 ]]; then
  pass "(6) diagnostic carries first-100-bytes excerpt for each file (both sentinel markers present)"
else
  err "(6) diagnostic missing body excerpt(s): ${T6_MISSING[*]}"
fi

# ---------------------------------------------------------------------------
# Case (7) — last-commit reference for each file.
#
# The label `last commit` is a verbatim element of the PRD FR-9
# structured diagnostic. Pin the substring's presence here; the
# downstream sha/author/timestamp shape is decided by the
# implementation but the label MUST appear.
#
# The test fixture is a real git repo with one commit — the resolver
# has a sha + author + timestamp to read. Two occurrences of the label
# are expected (one per file); the test pins ≥ 2 occurrences.
# ---------------------------------------------------------------------------
T7_LAST_COMMIT_HITS="$(grep -c -F -- "last commit" <<<"$T_STDERR" || true)"
if [[ "$T7_LAST_COMMIT_HITS" -ge 2 ]]; then
  pass "(7) diagnostic carries 'last commit' label for each file ($T7_LAST_COMMIT_HITS occurrence(s) ≥ 2)"
else
  err "(7) diagnostic missing per-file 'last commit' reference (got $T7_LAST_COMMIT_HITS occurrence(s), expected ≥ 2)"
fi

rm -rf "$TMP_BOTH"

harness::summary
