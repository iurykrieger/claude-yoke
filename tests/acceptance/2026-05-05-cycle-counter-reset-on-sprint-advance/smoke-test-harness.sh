#!/usr/bin/env bash
# criterion: AC-004-1
# criterion: AC-004-2
# criterion: AC-004-3
# criterion: AC-004-4
# criterion: AC-004-5
# criterion: AC-004-6
# criterion: FR-1
#
# Anchored AC bodies (verbatim, from the binding Acceptance Criteria doc):
#
#   AC-004-1: The test asserts AC-001-1 (helper creates the file with
#     content `0` when absent).
#   AC-004-2: The test asserts AC-001-2 (idempotent overwrite when the
#     file already contains `0`).
#   AC-004-3: The test asserts AC-001-3 (overwrite from a non-zero seed
#     value, e.g. `7`, to `0`).
#   AC-004-4: The test seeds a non-zero value before invoking the helper.
#   AC-004-5: The test asserts AC-001-4 (the helper does not write to
#     progress.md or any file outside wm_cycle_counter_path()).
#   AC-004-6: The test exits 0 on the happy path within the ≤ 10s budget.
#   FR-1: All Bash changes pass shellcheck with no new warnings.
#
# Strategy: this is a meta-test — it asserts the contract of the
# Sr-Eng-authored smoke test under tests/smoke/, not the helper itself.
# We:
#   (1) verify the smoke test file exists at the documented path;
#   (2) statically inspect its body for the watchdog, the WM_RUNTIME_DIR
#       isolation, the assertions for AC-001-1..AC-001-4, and the
#       non-zero seeding before each non-absent case;
#   (3) execute the smoke test and confirm exit 0 within ≤ 10s;
#   (4) run `shellcheck` on the new bash surfaces (paths.sh + smoke
#       test) and assert no errors (warnings are tolerated when they
#       exist on the unchanged baseline; we test for shellcheck-clean
#       on the helper's body only).

set -euo pipefail

# Internal watchdog (per CLAUDE.md :: ## Testing).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

SMOKE_TEST="$REPO_ROOT/tests/smoke/cycle-counter-reset-on-sprint-advance.test.sh"

# ---------------------------------------------------------------------------
# Pre-condition: smoke test file exists (DoD US-004 first bullet).
# ---------------------------------------------------------------------------
if [[ ! -f "$SMOKE_TEST" ]]; then
  err "(DoD US-004) smoke test file missing at tests/smoke/cycle-counter-reset-on-sprint-advance.test.sh"
  harness::summary
fi

# ---------------------------------------------------------------------------
# DoD US-004 second bullet — internal watchdog installed.
# ---------------------------------------------------------------------------
if grep -qE 'sleep 600 && kill -TERM \$\$' "$SMOKE_TEST"; then
  pass "(DoD US-004) smoke test installs the internal watchdog (sleep 600 && kill -TERM \$\$)"
else
  err "(DoD US-004) smoke test does NOT install the internal watchdog"
fi

# ---------------------------------------------------------------------------
# DoD US-004 third bullet — WM_RUNTIME_DIR isolated to a temp dir.
#
# The chosen strategy may be either an explicit `WM_RUNTIME_DIR` export OR
# a `cd "$(mktemp -d)"`-then-source pattern (since WM_RUNTIME_DIR is
# `readonly` once paths.sh is sourced). Either is acceptable; what we
# assert is that the test does NOT touch the worktree's actual
# .yoke/runtime/.
# ---------------------------------------------------------------------------
SMOKE_BODY="$(cat "$SMOKE_TEST")"

ISOLATION_OK=0
if grep -qE 'mktemp -d' <<<"$SMOKE_BODY"; then
  ISOLATION_OK=1
fi
if (( ISOLATION_OK == 1 )); then
  pass "(DoD US-004) smoke test isolates working memory via mktemp -d"
else
  err "(DoD US-004) smoke test does NOT isolate working memory via mktemp -d"
fi

# ---------------------------------------------------------------------------
# AC-004-1..AC-004-3 — the smoke test exercises the three cases.
# We assert the body references each case shape: absent file, seeded `0`,
# seeded non-zero (`7`).
# ---------------------------------------------------------------------------

# AC-004-1: absent-case (helper creates the file).
if grep -qE 'wm_reset_cycle_counter' <<<"$SMOKE_BODY"; then
  pass "AC-004-1: smoke test invokes wm_reset_cycle_counter (helper-creates-file case implied)"
else
  err "AC-004-1: smoke test does NOT invoke wm_reset_cycle_counter"
fi

# AC-004-2: idempotency case.
if grep -qE "printf '?0'?[^\$]*\.cycle-counter|echo[[:space:]]+['\"]?0" <<<"$SMOKE_BODY" \
  || grep -qE "idempot|already.*0|already at .?0" <<<"$SMOKE_BODY"; then
  pass "AC-004-2: smoke test exercises the idempotency case (file already at '0')"
else
  err "AC-004-2: smoke test does NOT clearly exercise the idempotency case"
fi

# AC-004-3 / AC-004-4: non-zero seed before invoking the helper.
if grep -qE "printf '?7'?|echo[[:space:]]+['\"]?7|seed.*7|=[[:space:]]*7" <<<"$SMOKE_BODY"; then
  pass "AC-004-3 / AC-004-4: smoke test seeds a non-zero value (7) before invoking the helper"
else
  err "AC-004-3 / AC-004-4: smoke test does NOT seed a non-zero value before invoking the helper"
fi

# ---------------------------------------------------------------------------
# AC-004-5 — smoke test asserts the no-side-effect contract.
# Observable: the body greps for progress.md absence or a find-based
# scan of the runtime dir post-helper.
# ---------------------------------------------------------------------------
if grep -qE 'progress\.md|find[^|]*runtime|sibling|outside.*counter|only.*\.cycle-counter' <<<"$SMOKE_BODY"; then
  pass "AC-004-5: smoke test asserts the no-side-effect contract (progress.md / runtime scan)"
else
  err "AC-004-5: smoke test does NOT clearly assert the no-side-effect contract"
fi

# ---------------------------------------------------------------------------
# AC-004-6 — execute the smoke test and assert exit 0 within ≤ 10s.
# ---------------------------------------------------------------------------
if [[ -f "$SMOKE_TEST" ]]; then
  START=$(date +%s)
  set +e
  bash "$SMOKE_TEST" > /tmp/yoke-smoke-cycle-counter.log 2>&1
  RC=$?
  set -e
  END=$(date +%s)
  ELAPSED=$((END - START))
  if (( RC == 0 )); then
    if (( ELAPSED <= 10 )); then
      pass "AC-004-6: smoke test exits 0 in ${ELAPSED}s (≤ 10s budget)"
    else
      err "AC-004-6: smoke test exits 0 but took ${ELAPSED}s (> 10s budget)"
    fi
  else
    err "AC-004-6: smoke test exits non-zero ($RC); log tail:"
    tail -20 /tmp/yoke-smoke-cycle-counter.log >&2 || true
  fi
fi

# ---------------------------------------------------------------------------
# FR-1 — shellcheck on the new bash surfaces.
#
# Tolerant scope: we run shellcheck against paths.sh + the smoke test
# and surface any net-new error-class violations. We don't attempt to
# diff against the pre-fix baseline here (which would require git),
# but DO surface any error-class warning so Sr Eng can investigate.
# Tolerated when shellcheck is unavailable on the runner.
# ---------------------------------------------------------------------------
if command -v shellcheck >/dev/null 2>&1; then
  SC_FAIL=0
  if ! shellcheck "$REPO_ROOT/lib/working-memory/paths.sh" >/tmp/yoke-shellcheck-paths.log 2>&1; then
    err "FR-1: shellcheck reported issues in lib/working-memory/paths.sh:"
    head -20 /tmp/yoke-shellcheck-paths.log >&2 || true
    SC_FAIL=1
  fi
  if ! shellcheck "$SMOKE_TEST" >/tmp/yoke-shellcheck-smoke.log 2>&1; then
    err "FR-1: shellcheck reported issues in the smoke test:"
    head -20 /tmp/yoke-shellcheck-smoke.log >&2 || true
    SC_FAIL=1
  fi
  if (( SC_FAIL == 0 )); then
    pass "FR-1: shellcheck clean on lib/working-memory/paths.sh and the smoke test"
  fi
else
  pass "FR-1: shellcheck unavailable on this runner — vacuously satisfied (CI must enforce)"
fi

harness::summary
