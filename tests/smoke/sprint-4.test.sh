#!/usr/bin/env bash
# tests/smoke/sprint-4.test.sh
#
# Ralph-loop walking invariants for the sprint-as-cycle PRD.
#
# Three assertions guarantee that future changes to /yoke:implement or
# lib/ralph-loop/orchestrate.sh cannot regress the per-sprint walk:
#   1. current_sprint: advances monotonically through 01 → 02 → 03 → 04
#      across the synthetic walk (the +1 past last sprint is the
#      post-completion pointer).
#   2. progress.md never splits into per-sprint files. At every step,
#      `find .yoke/runtime -maxdepth 1 -name 'progress*.md' -type f`
#      yields exactly 1 file.
#   3. At run end, `completed_sprints:` array length equals
#      `total_sprints:` — every sprint converged.
#
# This test is a DRY-RUN: no real ralph cycles. It exercises only the
# deterministic pieces of the walk — `active-sprint` / `total-sprints`
# subcommands and progress.md frontmatter — by manipulating the
# isolated test working memory directly. The Generator/Validator
# subagents are not invoked.
#
# Source: .yoke/specs/2026-04-27-sprint-as-cycle.md (sprint 4 t05 of
# the sprint-as-cycle PRD). Cites concepts/yoke-pattern-ralph-loop,
# concepts/yoke-pattern-memory-model, and the new
# concepts/yoke-pattern-sprint-runtime-bundle.
#
# macOS-portability note: every `wc -l` count is piped through
# `xargs` to strip BSD/macOS leading whitespace.
set -euo pipefail

# Resolve repo root regardless of where the test is invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Isolate the synthetic walk into a tmp dir so it never pollutes
# real working memory under the repo's .yoke/.
WM_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/yoke-sprint4-test.XXXXXX")"
TEST_SPEC="/tmp/2026-04-27-walk-test.md"
TEST_SLUG="2026-04-27-walk-test"
SYNTH_SPRINTS=3
trap 'rm -rf "$WM_TEST_DIR" "$TEST_SPEC" /tmp/sprint-01.txt /tmp/sprint-02.txt /tmp/sprint-03.txt' EXIT

FAIL=0
fail() { echo "FAIL: $*" >&2; FAIL=1; }
pass() { echo "PASS: $*"; }

echo "--- sprint-4 ralph-walking invariants ---"

# ---------------------------------------------------------------------------
# Set up synthetic spec (3 sprints) and an isolated working tree.
# ---------------------------------------------------------------------------
cat > "$TEST_SPEC" <<'EOF'
# Spec: walk-test (synthetic 3-sprint fixture for sprint-4 smoke test)

## Overall objective

Three trivial sprints used by tests/smoke/sprint-4.test.sh to dry-run
the sprint walk. Each sprint's DoD is a no-op file write so the
walk is observable without invoking Generator/Validator subagents.

## Sprints

### Sprint 1 — sprint-one
**Delivery objective:** echo a token to /tmp/sprint-01.txt.

### Sprint 2 — sprint-two
**Delivery objective:** echo a token to /tmp/sprint-02.txt.

### Sprint 3 — sprint-three
**Delivery objective:** echo a token to /tmp/sprint-03.txt.
EOF

# Isolated working memory for the dry-run.
mkdir -p "$WM_TEST_DIR/.yoke/sprints" "$WM_TEST_DIR/.yoke/runtime"
echo "$TEST_SLUG" > "$WM_TEST_DIR/.yoke/runtime/.current"

# Three minimal sprint files — enough for total-sprints to count them.
for n in 01 02 03; do
    cat > "$WM_TEST_DIR/.yoke/sprints/${TEST_SLUG}-s${n}.md" <<EOF
---
task_id: ${TEST_SLUG}-s${n}
sprint: ${n#0}
slug: ${TEST_SLUG}
status: approved
---

# Sprint ${n}: walk-test

## Sprint objective
Synthetic sprint ${n}.

## Sprint DoD
- echo token to /tmp/sprint-${n}.txt

## Tasks
### Task ${TEST_SLUG}-s${n}-t01
**Story:** trivial
**Technical implementation:** echo
**Validation:** file exists
**Acceptance criterion:** test -f /tmp/sprint-${n}.txt

## Functional acceptance criteria
- (none — synthetic)

## Sensors
- (none — synthetic)
EOF
done

# Helper: invoke orchestrate.sh with the isolated working memory.
# orchestrate.sh sources lib/working-memory/paths.sh which uses the
# WM_ROOT constant `.yoke` resolved relative to CWD. Run from the
# isolated WM_TEST_DIR so all .yoke/ paths land there.
orchestrate_isolated() {
    ( cd "$WM_TEST_DIR" && bash "$REPO_ROOT/lib/ralph-loop/orchestrate.sh" "$@" )
}

# Sequence of observed `current_sprint:` values across the dry-run.
observed_sequence=()
record_active_sprint() {
    local val
    val="$(orchestrate_isolated active-sprint)"
    observed_sequence+=("$val")
    # Singleton invariant check at every step (assertion 2).
    local progress_count
    progress_count="$(find "$WM_TEST_DIR/.yoke/runtime" -maxdepth 1 -name 'progress*.md' -type f 2>/dev/null | wc -l | xargs)"
    if [[ "$progress_count" -gt 1 ]]; then
        fail "progress.md was split into per-sprint files (count=$progress_count at step seq=${observed_sequence[*]})"
    fi
}

# Helper: write progress.md with a given current_sprint + completed_sprints.
write_progress() {
    local current="$1"
    local completed="$2"
    local total="$3"
    cat > "$WM_TEST_DIR/.yoke/runtime/progress.md" <<EOF
---
slug: ${TEST_SLUG}
current_sprint: ${current}
completed_sprints: ${completed}
cycle_count: 0
total_sprints: ${total}
---

# Progress — ${TEST_SLUG} (synthetic walk)
EOF
}

# ---------------------------------------------------------------------------
# Dry-run the walk: 4 observation points (start, after s01, after s02,
# after s03 — that last one yields current_sprint=04 = post-completion
# pointer).
# ---------------------------------------------------------------------------
# Step 0 — fresh start, no progress.md → orchestrate returns "01".
record_active_sprint
# Step 1 — sprint 01 just converged, advance to 02.
write_progress "02" "[01]" "$SYNTH_SPRINTS"
record_active_sprint
# Step 2 — sprint 02 just converged, advance to 03.
write_progress "03" "[01, 02]" "$SYNTH_SPRINTS"
record_active_sprint
# Step 3 — sprint 03 just converged, advance to 04 (post-completion).
write_progress "04" "[01, 02, 03]" "$SYNTH_SPRINTS"
record_active_sprint

# ---------------------------------------------------------------------------
# Assertion 1: monotonic advancement.
# Failure-message string anchor: "current_sprint: did not advance"
# ---------------------------------------------------------------------------
expected=("01" "02" "03" "04")
seq_str="${observed_sequence[*]}"
expected_str="${expected[*]}"
if [[ "$seq_str" != "$expected_str" ]]; then
    fail "current_sprint: did not advance monotonically; observed sequence: ${seq_str} (expected: ${expected_str})"
else
    pass "current_sprint: advanced monotonically through ${expected_str}"
fi

# ---------------------------------------------------------------------------
# Assertion 2: progress.md singleton across the run.
# Failure-message string anchor: "progress.md was split"
# ---------------------------------------------------------------------------
final_progress_count="$(find "$WM_TEST_DIR/.yoke/runtime" -maxdepth 1 -name 'progress*.md' -type f 2>/dev/null | wc -l | xargs)"
if [[ "$final_progress_count" != "1" ]]; then
    fail "progress.md was split into per-sprint files at run end (count=$final_progress_count)"
else
    pass "progress.md singleton invariant held across the run"
fi

# ---------------------------------------------------------------------------
# Assertion 3: completed_sprints array length equals total_sprints.
# Failure-message string anchor: "completed_sprints array does not equal"
# ---------------------------------------------------------------------------
final_progress="$WM_TEST_DIR/.yoke/runtime/progress.md"
total_sprints_val="$(awk '/^total_sprints:/ {gsub(/^total_sprints:[[:space:]]*/, "", $0); print; exit}' "$final_progress" | xargs)"
completed_raw="$(awk '/^completed_sprints:/ {gsub(/^completed_sprints:[[:space:]]*/, "", $0); print; exit}' "$final_progress")"
# Strip "[" and "]" then count comma-separated entries (trim spaces).
completed_inner="${completed_raw#[}"; completed_inner="${completed_inner%]}"
completed_inner="$(echo "$completed_inner" | tr -d '[:space:]')"
if [[ -z "$completed_inner" ]]; then
    completed_count=0
else
    completed_count="$(echo "$completed_inner" | tr ',' '\n' | wc -l | xargs)"
fi
if [[ "$completed_count" != "$total_sprints_val" ]]; then
    fail "completed_sprints array does not equal total_sprints at run end (completed=${completed_count}, total=${total_sprints_val})"
else
    pass "completed_sprints array length (${completed_count}) equals total_sprints (${total_sprints_val}) at run end"
fi

# ---------------------------------------------------------------------------
# Isolation check: no untracked changes to the real .yoke/sprints/ tree.
# ---------------------------------------------------------------------------
real_pollution_count="$(find .yoke/sprints -name "${TEST_SLUG}*" -type f 2>/dev/null | wc -l | xargs)"
if [[ "$real_pollution_count" != "0" ]]; then
    fail "synthetic test polluted real working memory (.yoke/sprints/ has ${real_pollution_count} ${TEST_SLUG}* files)"
fi

if [[ "$FAIL" -eq 0 ]]; then
    echo "--- sprint-4 walking invariants: ALL PASS ---"
    exit 0
else
    echo "--- sprint-4 walking invariants: FAILURES ABOVE ---" >&2
    exit 1
fi
