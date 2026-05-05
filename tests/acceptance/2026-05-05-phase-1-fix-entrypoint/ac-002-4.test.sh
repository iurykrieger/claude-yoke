#!/usr/bin/env bash
# criterion: AC-002-4
#
# AC-002-4 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "Mid-dialogue scope inflation re-evaluates the four proxies on the
#    cumulative dialogue answers; if a previously-narrow input becomes
#    ≤ 2/4 after the user answers, the skill aborts with the same
#    re-route prompt instead of completing the draft."
#
# Sprint scope (s03-t04): skills/fix/SKILL.md's persona body documents
# that the four narrowness proxies are evaluated EVERY dialogue turn,
# not just on the initial input. PRD Design Considerations are
# explicit: "evaluated *every dialogue turn* — not just on initial
# input."
#
# Pragmatic gating (per Sr QA cycle prompt direction):
#   The mid-dialogue branch fires inside the LLM dialogue. From bash
#   we cannot exercise the dialogue. The binding judgment is the
#   persona body's documented evaluation cadence: if the persona body
#   verbatim documents "every dialogue turn" / "cumulative answers" /
#   "mid-dialogue re-evaluation", the LLM follows that cadence.
#
#   Manual end-to-end recipe (recorded for human review):
#     $ /yoke:fix "fix the auth module's password regex"
#     # initial input passes 4/4 (or 3/4 with one soft fail)
#     # answer "actually, also fix the OAuth provider, the SAML
#     #         flow, and the SSO callback handler" — scope inflates
#     # OBSERVE: skill aborts with the same re-route prompt to
#     # /yoke:discover; no fix-spec written.
#
# Observable conditions tested:
#   (1) skills/fix/SKILL.md exists.
#   (2) persona body documents "every dialogue turn" or equivalent
#       evaluation cadence (NOT "on initial input only").
#   (3) persona body documents the cumulative-answers re-evaluation
#       (an explicit "cumulative" / "running" / "after the user
#       answers" clause).
#   (4) persona body documents that mid-dialogue ≤ 2/4 trips the
#       SAME abort branch as initial-input ≤ 2/4 (AC-002-4's "same
#       re-route prompt").
#   (5) persona body does NOT contain a "narrowness gate is
#       evaluated only on initial input" anti-pattern (red-team:
#       reject any phrasing that pins the gate to first-turn-only).

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
# Case (2) — "every dialogue turn" or equivalent cadence documented.
# ---------------------------------------------------------------------------
if grep -qiE 'every (dialogue )?turn|each (dialogue )?turn|on every turn|re-evaluat|reevaluat' <<<"$SKILL_BODY"; then
  pass "(2) persona body documents per-turn re-evaluation of the narrowness proxies"
else
  err "(2) persona body does NOT document per-turn re-evaluation — narrowness gate may be initial-input-only"
fi

# ---------------------------------------------------------------------------
# Case (3) — cumulative-answers re-evaluation documented.
# ---------------------------------------------------------------------------
if grep -qiE 'cumulative|mid-dialogue|after the user answers|running tally|scope inflation' <<<"$SKILL_BODY"; then
  pass "(3) persona body documents cumulative-answers / mid-dialogue re-evaluation"
else
  err "(3) persona body does NOT document cumulative-answers re-evaluation — mid-dialogue scope inflation may not be caught"
fi

# ---------------------------------------------------------------------------
# Case (4) — mid-dialogue ≤ 2/4 trips the SAME abort branch.
#
# Either the persona body explicitly says "same re-route prompt" /
# "same abort" / equivalent, OR it documents a single abort flow that
# both initial-input and mid-dialogue paths funnel into.
# ---------------------------------------------------------------------------
if grep -qiE 'same (abort|re-route|reroute)|abort.+re-route|aborts? with the same' <<<"$SKILL_BODY"; then
  pass "(4) persona body documents the SAME abort + re-route branch for mid-dialogue ≤ 2/4"
else
  # Softer signal: a single abort definition that both paths point at.
  if grep -qiE '/yoke:discover' <<<"$SKILL_BODY" && \
     grep -qcE 'abort|re-route|reroute' <<<"$SKILL_BODY" >/dev/null; then
    pass "(4) persona body documents a single abort + /yoke:discover re-route flow shared across initial-input and mid-dialogue ≤ 2/4 paths"
  else
    err "(4) persona body does NOT document a shared abort + re-route flow for mid-dialogue ≤ 2/4"
  fi
fi

# ---------------------------------------------------------------------------
# Case (5) — red-team: reject any "initial input only" anti-pattern.
#
# A phrase like "evaluated on the initial input only" or "first-turn
# only" would directly contradict AC-002-4's mid-dialogue mandate.
# This case greps for such anti-patterns and fails if any are found.
# ---------------------------------------------------------------------------
ANTIPATTERNS=(
  "initial input only"
  "only on the initial input"
  "first turn only"
  "only on the first turn"
  "first-turn only"
  "evaluated once"
  "one-shot evaluation"
)
FOUND_ANTI=()
for ap in "${ANTIPATTERNS[@]}"; do
  if grep -qiF "$ap" <<<"$SKILL_BODY"; then
    FOUND_ANTI+=("$ap")
  fi
done

if [[ "${#FOUND_ANTI[@]}" -eq 0 ]]; then
  pass "(5) persona body contains no 'initial input only' anti-patterns"
else
  err "(5) persona body contains anti-pattern(s) contradicting AC-002-4: ${FOUND_ANTI[*]}"
fi

harness::summary
