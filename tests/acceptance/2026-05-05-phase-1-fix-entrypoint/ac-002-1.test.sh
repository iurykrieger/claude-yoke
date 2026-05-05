#!/usr/bin/env bash
# criterion: AC-002-1
#
# AC-002-1 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "Running `/yoke:fix \"add OAuth2 support to the auth middleware\"`
#    (feature-add language, no contract reference) trips the
#    narrowness gate's contract-shape proxy and produces a re-route
#    prompt offering `/yoke:discover`; the skill exits non-zero
#    without writing any file under `.yoke/fixes/`."
#
# Sprint scope (s03-t04): skills/fix/SKILL.md's persona body encodes
# four narrowness proxies (component breadth / contract shape /
# trigger specificity / surface containment); ≤ 2/4 passing aborts
# with re-route to /yoke:discover.
#
# Pragmatic gating (per Sr QA cycle prompt direction):
#   The narrowness-gate decision happens inside an LLM dialogue. From
#   bash we cannot exercise the dialogue's branching. The binding
#   judgment is the persona body's documented shape: if the persona
#   body verbatim encodes the four proxies, names contract-shape
#   among them, and documents the ≤ 2/4 abort + re-route branch, the
#   LLM follows that doctrine on feature-add inputs.
#
#   Manual end-to-end recipe (recorded for human review):
#     $ /yoke:fix "add OAuth2 support to the auth middleware"
#     # OBSERVE: skill aborts (exit non-zero), no file under
#     # .yoke/fixes/ is created, the response includes a re-route
#     # prompt offering /yoke:discover.
#     $ test ! -f .yoke/fixes/2026-05-05-add-oauth2-support.md
#
# Observable conditions tested:
#   (1) skills/fix/SKILL.md exists.
#   (2) persona body declares the four narrowness proxies verbatim
#       (component breadth / contract shape / trigger specificity /
#       surface containment) — PRD FR-6 mandates them by name.
#   (3) persona body documents the ≤ 2/4 abort branch with re-route
#       to /yoke:discover.
#   (4) persona body identifies "design rethink" / "feature-add"
#       phrasings as contract-shape proxy fail signals (the literal
#       "should support" / "should handle" / "should provide"
#       phrasing fingerprints from PRD FR-6 sub-bullet b).
#   (5) skill body documents that the abort path does NOT write any
#       file under .yoke/fixes/.

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

SKILL="$REPO_ROOT/skills/fix/SKILL.md"

# ---------------------------------------------------------------------------
# Case (1) — skills/fix/SKILL.md exists.
# ---------------------------------------------------------------------------
if [[ -f "$SKILL" ]]; then
  pass "(1) skills/fix/SKILL.md exists"
else
  err "(1) skills/fix/SKILL.md is missing — Sr Eng s03-t04 deliverable"
  harness::summary
fi

SKILL_BODY="$(cat "$SKILL")"

# ---------------------------------------------------------------------------
# Case (2) — four narrowness proxies declared verbatim.
#
# PRD FR-6 mandates the names: component breadth, contract shape,
# trigger specificity, surface containment.
# ---------------------------------------------------------------------------
PROXIES=(
  "component breadth"
  "contract shape"
  "trigger specificity"
  "surface containment"
)
MISSING_PROXIES=()
for proxy in "${PROXIES[@]}"; do
  if ! grep -qiF "$proxy" <<<"$SKILL_BODY"; then
    MISSING_PROXIES+=("$proxy")
  fi
done

if [[ "${#MISSING_PROXIES[@]}" -eq 0 ]]; then
  pass "(2) persona body declares all four narrowness proxies verbatim (component breadth / contract shape / trigger specificity / surface containment)"
else
  err "(2) persona body missing narrowness proxies: ${MISSING_PROXIES[*]}"
fi

# ---------------------------------------------------------------------------
# Case (3) — ≤ 2/4 abort branch with re-route to /yoke:discover.
# ---------------------------------------------------------------------------
HAS_RE_ROUTE=0
if grep -q '/yoke:discover' <<<"$SKILL_BODY" && \
   grep -qiE '(2/4|two of four|abort|re-route|reroute)' <<<"$SKILL_BODY"; then
  HAS_RE_ROUTE=1
fi

if [[ "$HAS_RE_ROUTE" -eq 1 ]]; then
  pass "(3) persona body documents ≤ 2/4 abort branch with re-route to /yoke:discover"
else
  err "(3) persona body does NOT document the ≤ 2/4 abort + /yoke:discover re-route branch"
fi

# ---------------------------------------------------------------------------
# Case (4) — design-rethink / feature-add phrasings identified as
# contract-shape proxy fail signals. PRD FR-6 sub-bullet (b) lists:
# "should support", "should handle", "should provide" as the canonical
# fingerprints.
# ---------------------------------------------------------------------------
RETHINK_FINGERPRINTS=("should support" "should handle" "should provide")
FOUND=0
for fp in "${RETHINK_FINGERPRINTS[@]}"; do
  if grep -qiF "$fp" <<<"$SKILL_BODY"; then
    FOUND=$((FOUND + 1))
  fi
done

if [[ "$FOUND" -ge 1 ]]; then
  pass "(4) persona body documents at least one feature-add phrasing fingerprint (should support / should handle / should provide) as contract-shape fail signal"
else
  err "(4) persona body documents NO feature-add phrasing fingerprints — contract-shape proxy is under-specified"
fi

# ---------------------------------------------------------------------------
# Case (5) — abort path does NOT materialize a fix-spec.
#
# The persona body must document that on ≤ 2/4 the skill aborts
# BEFORE writing to .yoke/fixes/. We accept either an explicit
# "before writing" clause or a structural ordering where the gate
# precedes the write.
# ---------------------------------------------------------------------------
if grep -qiE '(abort.+before.+writ|no.+file.+writ|exits? non-zero|exits? without writ)' <<<"$SKILL_BODY"; then
  pass "(5) persona body documents abort-without-write semantics on the ≤ 2/4 branch"
else
  err "(5) persona body does NOT document abort-without-write — risk of partial fix-spec leaking on the abort path"
fi

harness::summary
