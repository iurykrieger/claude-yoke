#!/usr/bin/env bash
# criterion: AC-002-1
# criterion: AC-002-2
# criterion: AC-002-3
# criterion: FR-5
#
# Anchored AC bodies (verbatim, from the binding Acceptance Criteria doc):
#
#   AC-002-1: A literal grep for `wm_reset_cycle_counter` in
#     skills/implement/SKILL.md returns at least 1 match.
#   AC-002-2: The amended prose places the helper invocation *after* the
#     `completed_sprints:` append and the `current_sprint:` increment in
#     the step-9 sequence.
#   AC-002-3: The prose change does not contradict
#     concepts/yoke-pattern-sprint-runtime-bundle (canonical memory):
#     sprint-advance still resets the counter; hard-bound exhaustion
#     still fires Trigger 4 keyed on the active sprint.
#   FR-5: No file under .yoke/acceptance-contracts/ is created or
#     modified by this delivery.

set -euo pipefail

# Internal watchdog (per CLAUDE.md :: ## Testing).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

SKILL="$REPO_ROOT/skills/implement/SKILL.md"

# ---------------------------------------------------------------------------
# Pre-condition: skills/implement/SKILL.md exists.
# ---------------------------------------------------------------------------
if [[ ! -f "$SKILL" ]]; then
  err "skills/implement/SKILL.md missing — Sr Eng deliverable absent"
  harness::summary
fi

# ---------------------------------------------------------------------------
# AC-002-1 — at least one literal occurrence of wm_reset_cycle_counter.
# ---------------------------------------------------------------------------
MATCH_COUNT=$(grep -c 'wm_reset_cycle_counter' "$SKILL" || true)
if (( MATCH_COUNT >= 1 )); then
  pass "AC-002-1: 'wm_reset_cycle_counter' appears $MATCH_COUNT time(s) in skills/implement/SKILL.md (>= 1 required)"
else
  err "AC-002-1: 'wm_reset_cycle_counter' does NOT appear in skills/implement/SKILL.md"
fi

# ---------------------------------------------------------------------------
# AC-002-2 — helper invocation appears AFTER `completed_sprints:` append
# and `current_sprint:` increment in the step-9 sequence.
#
# The fix-spec / spec call out three touch points (lines 74, 193, 425–428).
# The dominant-risk anchor is step 9 (~ line 425). We assert that, in the
# textual order of the file, the FIRST mention of `wm_reset_cycle_counter`
# at or after line 200 is preceded by `completed_sprints:` and
# `current_sprint:` mentions inside the same H3 step block. The simpler
# observable: in the file's full-text order, the LAST occurrence of
# `wm_reset_cycle_counter` falls after the LAST `completed_sprints:`
# append/`current_sprint:` increment in the step-9 region. We use the
# step-9 H3 anchor (`### 9.` or step-9 section header) as the regional
# bound when present, falling back to the global last-occurrence rule.
# ---------------------------------------------------------------------------
HELPER_LNS=$(grep -n 'wm_reset_cycle_counter' "$SKILL" | cut -d: -f1 || true)
COMPLETED_LNS=$(grep -nE 'completed_sprints' "$SKILL" | cut -d: -f1 || true)
CURRENT_LNS=$(grep -nE 'current_sprint' "$SKILL" | cut -d: -f1 || true)

if [[ -z "$HELPER_LNS" ]]; then
  err "AC-002-2: cannot evaluate ordering — no helper mention found"
elif [[ -z "$COMPLETED_LNS" || -z "$CURRENT_LNS" ]]; then
  err "AC-002-2: cannot evaluate ordering — completed_sprints / current_sprint markers missing"
else
  # Reading frame: the step-9 narrative (per spec) sits in the 410–450
  # line band. Find the helper mention closest to (but at-or-after) the
  # step-9 anchor; that mention must come AFTER the step-9
  # completed_sprints append AND the current_sprint increment.
  STEP9_LN=$(grep -nE '^9\. \*\*Stop check' "$SKILL" | head -1 | cut -d: -f1 || true)
  if [[ -z "$STEP9_LN" ]]; then
    # Fallback: the spec's anchor lines 425-428 region.
    STEP9_LN=410
  fi
  # First helper mention after step-9 anchor.
  HELPER_AFTER=$(awk -v anchor="$STEP9_LN" '/wm_reset_cycle_counter/ && NR >= anchor {print NR; exit}' "$SKILL" || true)
  # Last completed_sprints / current_sprint mentions before that helper line,
  # but at-or-after the step-9 anchor.
  if [[ -n "$HELPER_AFTER" ]]; then
    COMPLETED_BEFORE_HELPER=$(awk -v anchor="$STEP9_LN" -v helper="$HELPER_AFTER" '/completed_sprints/ && NR >= anchor && NR < helper {ln=NR} END {print ln+0}' "$SKILL")
    CURRENT_BEFORE_HELPER=$(awk -v anchor="$STEP9_LN" -v helper="$HELPER_AFTER" '/current_sprint/ && NR >= anchor && NR < helper {ln=NR} END {print ln+0}' "$SKILL")
    if (( COMPLETED_BEFORE_HELPER > 0 && CURRENT_BEFORE_HELPER > 0 )); then
      pass "AC-002-2: helper mention at line $HELPER_AFTER follows step-9 completed_sprints (line $COMPLETED_BEFORE_HELPER) and current_sprint (line $CURRENT_BEFORE_HELPER) within the same step block"
    else
      err "AC-002-2: helper at line $HELPER_AFTER does NOT follow completed_sprints/current_sprint within the step-9 region (completed_before=$COMPLETED_BEFORE_HELPER, current_before=$CURRENT_BEFORE_HELPER)"
    fi
  else
    err "AC-002-2: no helper mention found at-or-after the step-9 anchor (line $STEP9_LN); helper appears only outside the convergence step"
  fi
fi

# ---------------------------------------------------------------------------
# AC-002-3 — prose does not contradict
# concepts/yoke-pattern-sprint-runtime-bundle.
#
# Observable conditions (testable on the file body):
#   (a) The phrase asserting "sprint advance resets cycle_count" or
#       equivalent semantics is preserved (the canonized doctrine
#       mandates the reset).
#   (b) Trigger-4 / hard-bound prose still keys on the active sprint
#       (i.e. the `--active-sprint "$current_sprint"` invocation in the
#       inner-loop pseudo-code is preserved).
# ---------------------------------------------------------------------------
SKILL_BODY="$(cat "$SKILL")"

CONDITIONS_FAILED=0

# (a) Doctrine-anchored reset prose preserved.
if grep -qE 'reset[^\n]*cycle_count|cycle_count[^\n]*0|reset.*\.cycle-counter' <<<"$SKILL_BODY"; then
  :
else
  CONDITIONS_FAILED=$((CONDITIONS_FAILED + 1))
  err "AC-002-3 (a): the 'reset cycle_count to 0' doctrine prose was elided"
fi

# (b) Trigger-4 keyed on active sprint.
if grep -qE 'active-sprint.*current_sprint|--reason hard-bound' <<<"$SKILL_BODY"; then
  :
else
  CONDITIONS_FAILED=$((CONDITIONS_FAILED + 1))
  err "AC-002-3 (b): the Trigger-4 active-sprint keying prose was elided"
fi

# (c) No new ## section heading was introduced (DoD US-002 third bullet)
# — the SKILL.md H2 surface is stable across this change. We pin the H2
# count snapshot to the pre-fix baseline; if the file's H2 count drifts
# we surface it as an AC-002-3 violation.
H2_COUNT=$(grep -cE '^## ' "$SKILL")
# Pre-fix baseline H2 count is 5 (Inputs, Process, Outputs, Failure modes
# / escalation, References) — this is a structural invariant of the
# skill, not a per-fix tunable.
if (( H2_COUNT == 5 )); then
  pass "AC-002-3 (c): SKILL.md H2 section count unchanged ($H2_COUNT)"
else
  CONDITIONS_FAILED=$((CONDITIONS_FAILED + 1))
  err "AC-002-3 (c): SKILL.md H2 count drifted to $H2_COUNT (expected 5)"
fi

# (d) No new `### Task` anchor and no `## Sprints` heading was introduced
# (DoD US-002 fourth bullet).
if grep -qE '^### Task ' "$SKILL"; then
  CONDITIONS_FAILED=$((CONDITIONS_FAILED + 1))
  err "AC-002-3 (d): SKILL.md introduced a '### Task ' anchor (forbidden by DoD)"
fi
if grep -qE '^## Sprints' "$SKILL"; then
  CONDITIONS_FAILED=$((CONDITIONS_FAILED + 1))
  err "AC-002-3 (d): SKILL.md introduced a '## Sprints' section (forbidden by DoD)"
fi

if (( CONDITIONS_FAILED == 0 )); then
  pass "AC-002-3: prose change preserves doctrine (reset semantic + Trigger-4 active-sprint keying + no new H2 / Task anchor)"
fi

# ---------------------------------------------------------------------------
# FR-5 — no file under .yoke/acceptance-contracts/ created or modified by
# this delivery. We assert no file with a 2026-05-05 prefix exists in
# the legacy directory for this slug (the directory may carry frozen
# historical files for unrelated slugs).
# ---------------------------------------------------------------------------
LEGACY_FILE="$REPO_ROOT/.yoke/acceptance-contracts/2026-05-05-cycle-counter-reset-on-sprint-advance.md"
if [[ -e "$LEGACY_FILE" ]]; then
  err "FR-5: legacy file exists at .yoke/acceptance-contracts/ for this slug (forbidden)"
else
  pass "FR-5: no .yoke/acceptance-contracts/ file for this slug (v4.0.0 cutover honored)"
fi

harness::summary
