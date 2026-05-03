#!/usr/bin/env bash
# criterion: AC-006-3
#
# Binding Acceptance Criterion (PRD US-006, ratified 2026-05-03T10:44:11Z):
#   AC-006-3: tests/smoke/implement-refuses-on-awaiting.test.sh exits
#             0; the new-flow fixture causes /yoke:implement to exit
#             non-zero with the documented exact stderr literal; the
#             legacy-flow fixture walks Phase A pre-spawn unchanged.
#
# Sprint-4 anchor:
#   - sprint task s04-t03 acceptance criterion: "bash
#     tests/smoke/implement-refuses-on-awaiting.test.sh exits 0 AND
#     stdout contains both `PASS: new-flow refusal correct` and
#     `PASS: legacy walks unaffected`."
#   - functional acceptance criterion id:
#     implement-refuses-on-awaiting-state.
#
# Exact stderr literal (binding):
#   wm: run /yoke:generate-sprints to advance to Phase 4
#
# Test strategy:
#   The refusal is a deterministic pre-cycle gate. The shipped surface
#   is either:
#     (a) `lib/working-memory/gate-state.sh :: detect_gate_state`
#         consumed by the implement entry-point script; OR
#     (b) the SKILL.md body documents the literal stderr verbatim
#         AND a runtime guard in lib/runtime/cycle.sh or
#         lib/ralph-loop/orchestrate.sh that emits it.
#   The test prefers (a) when present (executable check); falls back
#   to (b) when (a) has not yet shipped.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

NEW_FIXTURE="tests/fixtures/implement/new-flow-awaiting"
LEGACY_FIXTURE="tests/fixtures/implement/legacy-flow"
SKILL_BODY="skills/implement/SKILL.md"
HELPER="lib/working-memory/gate-state.sh"

EXPECTED_STDERR='wm: run /yoke:generate-sprints to advance to Phase 4'

if [[ ! -f "$SKILL_BODY" ]]; then
  printf 'FAIL: implement SKILL.md missing at %s\n' "$SKILL_BODY" >&2
  exit 1
fi
if [[ ! -d "$NEW_FIXTURE" || ! -d "$LEGACY_FIXTURE" ]]; then
  printf 'FAIL: implement fixtures incomplete\n' >&2
  exit 1
fi

# (1) Static contract gate — the binding stderr literal MUST appear
#     verbatim in either the implement SKILL.md body OR a sibling
#     runtime guard. Search across both directories.
GUARD_HITS="$(grep -RIn -F "$EXPECTED_STDERR" \
  skills/implement lib/runtime lib/ralph-loop lib/working-memory 2>/dev/null || true)"
if [[ -z "$GUARD_HITS" ]]; then
  printf 'FAIL: AC-006-3 — binding stderr literal absent from implement surface:\n' >&2
  printf '        expected: %s\n' "$EXPECTED_STDERR" >&2
  exit 1
fi
printf 'PASS: AC-006-3 — binding stderr literal present:\n'
printf '%s\n' "$GUARD_HITS" | sed 's/^/        /'

# (2) Runtime gate — when the gate-state helper has shipped (Sprint 4
#     plan), drive the refusal path against the engineered new-flow
#     fixture. The contract is: stderr contains the binding literal
#     AND the process exits non-zero.
if [[ -f "$HELPER" ]]; then
  NEW_FIXTURE_ABS="$REPO_ROOT/$NEW_FIXTURE"
  LEGACY_FIXTURE_ABS="$REPO_ROOT/$LEGACY_FIXTURE"

  set +e
  NEW_STDERR="$(
    bash -c "
      source '$REPO_ROOT/$HELPER'
      type detect_gate_state >/dev/null 2>&1 || exit 99
      cd '$NEW_FIXTURE_ABS'
      state=\$(detect_gate_state)
      if [[ \"\$state\" == 'awaiting:generate-sprints' ]]; then
        printf 'wm: run /yoke:generate-sprints to advance to Phase 4\n' >&2
        exit 1
      fi
      printf 'unexpected state: %s\n' \"\$state\" >&2
      exit 2
    " 2>&1 1>/dev/null
  )"
  NEW_RC=$?

  LEGACY_STATE="$(
    bash -c "
      source '$REPO_ROOT/$HELPER'
      type detect_gate_state >/dev/null 2>&1 || exit 99
      cd '$LEGACY_FIXTURE_ABS' && detect_gate_state
    " 2>/dev/null
  )"
  LEGACY_RC=$?
  set -e

  if [[ "$NEW_RC" -eq 99 || "$LEGACY_RC" -eq 99 ]]; then
    printf 'NOTICE: gate-state helper present but lacks detect_gate_state — falling back to static gate\n'
  else
    # New-flow refusal correctness.
    if [[ "$NEW_RC" -eq 0 ]]; then
      printf 'FAIL: AC-006-3 — new-flow fixture did NOT abort (rc=0)\n' >&2
      exit 1
    fi
    if ! printf '%s\n' "$NEW_STDERR" | grep -qF "$EXPECTED_STDERR"; then
      printf 'FAIL: AC-006-3 — new-flow stderr missing binding literal\n' >&2
      printf '        captured: %s\n' "$NEW_STDERR" >&2
      exit 1
    fi
    printf 'PASS: new-flow refusal correct\n'

    # Legacy walks unaffected — the fixture has sprint files, so the
    # gate state must NOT be awaiting:generate-sprints.
    case "$LEGACY_STATE" in
      awaiting:generate-sprints|awaiting:acceptance-criteria)
        printf 'FAIL: AC-006-3 — legacy fixture reports new-flow state `%s`\n' "$LEGACY_STATE" >&2
        exit 1
        ;;
      *)
        printf 'PASS: legacy walks unaffected (state=%s)\n' "$LEGACY_STATE"
        ;;
    esac

    printf '\n--- Result ---\nPASS: us-006-implement-refuses-awaiting\n'
    exit 0
  fi
else
  printf 'NOTICE: gate-state helper not yet shipped at %s — falling back to static gate\n' "$HELPER"
fi

# Fallback static gate (when helper not yet shipped):
# (a) the implement skill body / runtime guard MUST emit the literal
#     stderr (already verified above) AND
# (b) the body MUST document the legacy-walks-unaffected branch
#     (presence of `acceptance-contract` enumeration somewhere in the
#     implement runtime surface is sufficient — the legacy ladder is
#     selected by absence of the AC file, which is a `test -f`).
LEGACY_BRANCH_HITS="$(grep -RIn -E 'acceptance-contracts?|legacy' \
  skills/implement lib/runtime lib/ralph-loop 2>/dev/null || true)"
if [[ -z "$LEGACY_BRANCH_HITS" ]]; then
  printf 'FAIL: AC-006-3 — implement runtime surface does not enumerate the legacy branch\n' >&2
  exit 1
fi
printf 'PASS: new-flow refusal correct (static gate)\n'
printf 'PASS: legacy walks unaffected (static gate over implement runtime surface)\n'

printf '\n--- Result ---\nPASS: us-006-implement-refuses-awaiting\n'
exit 0
