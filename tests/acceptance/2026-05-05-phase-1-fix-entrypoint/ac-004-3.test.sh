#!/usr/bin/env bash
# criterion: AC-004-3
#
# AC-004-3 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "wm_set_active invoked with a slug whose archives contain both
#    files refuses to record .yoke/runtime/.current and prints the
#    same diagnostic; the file at .yoke/runtime/.current is not
#    modified."
#
# Sprint scope (s02-t02): wm_set_active gains a write-time invariant
# gate that detects the both-files-exist case and refuses to record.
#
# Observable conditions tested:
#   (1) `wm_set_active` symbol is exported by paths.sh (sanity — it
#       was already present; the test guards against accidental
#       removal).
#   (2) When both PRD and fix-spec exist for <slug>, calling
#       `wm_set_active "<slug>"` exits non-zero.
#   (3) Stderr begins exactly with `wm: ambiguous Phase-1 state for
#       slug '<slug>'` (same diagnostic family as AC-004-1; FR-9a
#       prints the FR-9 diagnostic verbatim).
#   (4) When `.yoke/runtime/.current` does NOT pre-exist, the failed
#       call MUST NOT create it (no truncation, no half-write).
#   (5) When `.yoke/runtime/.current` pre-exists with a sentinel
#       payload, the failed call MUST leave the file's bytes
#       bit-for-bit unchanged. Pin this with a sha256 comparison
#       across the call boundary — a partial write that happens to
#       match the sentinel byte-count would be caught.
#   (6) On the unambiguous case (only one Phase-1 archive exists),
#       `wm_set_active` MUST still write `.current` — the gate must
#       not regress the happy path. Negative-control: prove the gate
#       fires only on the both-exist case.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
#   tests/acceptance/<slug>/ac-004-3.test.sh -> ../../..
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
HAPPY_SLUG="2026-05-05-fix-only-prd-here"
EXPECTED_PREFIX="wm: ambiguous Phase-1 state for slug '${VALID_SLUG}'"
SENTINEL_PAYLOAD="2026-05-05-pre-existing-active-slug"

# Helper to compute a stable digest of a file's bytes (sha256 column 1).
# Falls back to a wc-based fingerprint when shasum is missing (rare on
# CI, but keeps the test portable).
_digest() {
  local f="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" 2>/dev/null | awk '{print $1}'
  else
    # Portable last-resort fingerprint.
    wc -c < "$f" 2>/dev/null | tr -d '[:space:]'
    printf ':'
    cksum < "$f" 2>/dev/null | awk '{print $1}'
  fi
}

# ---------------------------------------------------------------------------
# Case (1) — wm_set_active symbol is still exported.
# ---------------------------------------------------------------------------
TMP_PRECHECK=$(mktemp -d)
set +e
(
  cd "$TMP_PRECHECK"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  declare -F wm_set_active >/dev/null
)
PRECHECK_RC=$?
set -e
rm -rf "$TMP_PRECHECK"

if [[ "$PRECHECK_RC" -eq 0 ]]; then
  pass "(1) wm_set_active is exported by lib/working-memory/paths.sh"
else
  err "(1) wm_set_active is NOT exported by lib/working-memory/paths.sh — declare -F returned $PRECHECK_RC"
  harness::summary
fi

# ---------------------------------------------------------------------------
# Build a tmpdir with BOTH fixtures present and a pre-existing
# `.current` file carrying a sentinel payload. The test asserts the
# sentinel is preserved bit-for-bit across the failed call.
# ---------------------------------------------------------------------------
TMP_BOTH=$(mktemp -d)
T_OUT="$TMP_BOTH/stdout"
T_ERR="$TMP_BOTH/stderr"

mkdir -p "$TMP_BOTH/.yoke/prds" \
         "$TMP_BOTH/.yoke/fixes" \
         "$TMP_BOTH/.yoke/runtime"
printf '# PRD body for %s\n' "$VALID_SLUG" > "$TMP_BOTH/.yoke/prds/${VALID_SLUG}.md"
printf '# Fix-spec body for %s\n' "$VALID_SLUG" > "$TMP_BOTH/.yoke/fixes/${VALID_SLUG}.md"
printf '%s' "$SENTINEL_PAYLOAD" > "$TMP_BOTH/.yoke/runtime/.current"

CURRENT_FILE="$TMP_BOTH/.yoke/runtime/.current"
DIGEST_BEFORE="$(_digest "$CURRENT_FILE")"

set +e
(
  cd "$TMP_BOTH"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_set_active "$VALID_SLUG"
) >"$T_OUT" 2>"$T_ERR"
T_RC=$?
set -e

T_STDOUT="$(cat "$T_OUT")"
T_STDERR="$(cat "$T_ERR")"

# ---------------------------------------------------------------------------
# Case (2) — non-zero exit on the both-exist write attempt.
# ---------------------------------------------------------------------------
if [[ "$T_RC" -ne 0 ]]; then
  pass "(2) wm_set_active '$VALID_SLUG' (both files) aborts non-zero"
else
  err "(2) wm_set_active both-exist write returned rc=0 (expected non-zero) stderr='$T_STDERR'"
fi

# ---------------------------------------------------------------------------
# Case (3) — stderr begins with the AC-004-1 ambiguous-state prefix.
#
# FR-9a mandates wm_set_active prints the FR-9 diagnostic VERBATIM.
# Same prefix as AC-004-1's resolver path.
# ---------------------------------------------------------------------------
if [[ "$T_STDERR" == "$EXPECTED_PREFIX"* ]]; then
  pass "(3) wm_set_active diagnostic begins with '$EXPECTED_PREFIX'"
else
  err "(3) wm_set_active diagnostic missing AC-004-1 prefix — stderr-head='$(printf '%s' "$T_STDERR" | head -c 200)' expected='$EXPECTED_PREFIX'"
fi

# ---------------------------------------------------------------------------
# Case (4) — preserved `.current` content (sentinel intact).
#
# Compare sha256 across the call boundary. A partial write that
# overwrites the sentinel with the new slug's prefix would be caught.
# ---------------------------------------------------------------------------
DIGEST_AFTER="$(_digest "$CURRENT_FILE")"
ACTUAL_PAYLOAD="$(cat "$CURRENT_FILE")"

if [[ "$DIGEST_BEFORE" == "$DIGEST_AFTER" && "$ACTUAL_PAYLOAD" == "$SENTINEL_PAYLOAD" ]]; then
  pass "(4) .yoke/runtime/.current preserved bit-for-bit (sha256 matches; payload unchanged)"
else
  err "(4) .yoke/runtime/.current was modified by the refused write — digest before='$DIGEST_BEFORE' after='$DIGEST_AFTER' payload='$ACTUAL_PAYLOAD' sentinel='$SENTINEL_PAYLOAD'"
fi

rm -rf "$TMP_BOTH"

# ---------------------------------------------------------------------------
# Case (5) — failed call MUST NOT create `.current` when it does not
# pre-exist.
#
# Same conditions as Case (4) but `.current` is absent at call time.
# A bug that creates the file with an empty body before the refusal
# would be caught here.
# ---------------------------------------------------------------------------
TMP_BOTH_NO_CURRENT=$(mktemp -d)
mkdir -p "$TMP_BOTH_NO_CURRENT/.yoke/prds" \
         "$TMP_BOTH_NO_CURRENT/.yoke/fixes" \
         "$TMP_BOTH_NO_CURRENT/.yoke/runtime"
printf '# PRD body\n' > "$TMP_BOTH_NO_CURRENT/.yoke/prds/${VALID_SLUG}.md"
printf '# Fix-spec body\n' > "$TMP_BOTH_NO_CURRENT/.yoke/fixes/${VALID_SLUG}.md"

set +e
(
  cd "$TMP_BOTH_NO_CURRENT"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_set_active "$VALID_SLUG"
) >/dev/null 2>"$TMP_BOTH_NO_CURRENT/stderr"
T5_RC=$?
set -e

if [[ "$T5_RC" -ne 0 ]] && [[ ! -e "$TMP_BOTH_NO_CURRENT/.yoke/runtime/.current" ]]; then
  pass "(5) refused wm_set_active does NOT create .yoke/runtime/.current when absent (rc=$T5_RC, file absent)"
else
  if [[ -e "$TMP_BOTH_NO_CURRENT/.yoke/runtime/.current" ]]; then
    err "(5) refused wm_set_active leaked a created .yoke/runtime/.current (rc=$T5_RC, contents='$(cat "$TMP_BOTH_NO_CURRENT/.yoke/runtime/.current")')"
  else
    err "(5) wm_set_active did not refuse rc=$T5_RC stderr='$(cat "$TMP_BOTH_NO_CURRENT/stderr")'"
  fi
fi

rm -rf "$TMP_BOTH_NO_CURRENT"

# ---------------------------------------------------------------------------
# Case (6) — happy path: only one Phase-1 archive exists, wm_set_active
# writes `.current` as documented.
#
# Negative-control: the gate fires ONLY on the both-exist case. Without
# this case, a buggy implementation could refuse every write and pass
# Cases (2)–(5).
# ---------------------------------------------------------------------------
TMP_HAPPY=$(mktemp -d)
mkdir -p "$TMP_HAPPY/.yoke/prds" \
         "$TMP_HAPPY/.yoke/fixes" \
         "$TMP_HAPPY/.yoke/runtime"
# Only PRD exists for this slug.
printf '# PRD body\n' > "$TMP_HAPPY/.yoke/prds/${HAPPY_SLUG}.md"

set +e
(
  cd "$TMP_HAPPY"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_set_active "$HAPPY_SLUG"
) >/dev/null 2>"$TMP_HAPPY/stderr"
T6_RC=$?
set -e

T6_CURRENT_FILE="$TMP_HAPPY/.yoke/runtime/.current"
if [[ "$T6_RC" -eq 0 ]] && [[ -f "$T6_CURRENT_FILE" ]] && [[ "$(cat "$T6_CURRENT_FILE")" == "$HAPPY_SLUG" ]]; then
  pass "(6) wm_set_active writes .current on the unambiguous happy path (only-PRD case)"
else
  err "(6) wm_set_active happy-path regressed rc=$T6_RC current-exists=$([[ -f "$T6_CURRENT_FILE" ]] && echo yes || echo no) payload='$([[ -f "$T6_CURRENT_FILE" ]] && cat "$T6_CURRENT_FILE" || echo NA)' stderr='$(cat "$TMP_HAPPY/stderr")'"
fi

rm -rf "$TMP_HAPPY"

harness::summary
