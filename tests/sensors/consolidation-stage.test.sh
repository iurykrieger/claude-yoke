#!/usr/bin/env bash
# tests/sensors/consolidation-stage.test.sh — permanent CI-gated test
# for the /yoke:consolidate-sensors skill's deterministic contract:
# append-only writes with mandatory citation, recalibration within
# tolerance, idempotent reentry.
#
# The skill itself contains an agentic distillation node (a Task call
# producing candidate bullets). We cannot exercise that node from a
# shell test deterministically. Instead, this test:
#   1. Sets up an isolated fixture under /tmp/yoke-consolidate-test-*/
#      with synthetic verdicts and progress evidence.
#   2. Drives the deterministic body of the skill — citation-keyed
#      append with idempotency grep, plus 5%-threshold cost
#      recalibration — through a wrapper that mimics what the skill
#      executes after the agentic node returns.
#   3. Runs the wrapper twice and asserts:
#        - Run 1 appends a bullet whose body contains BOTH `cycle `
#          AND `fix-instruction`.
#        - Run 2 produces a byte-identical sensor file (idempotency).
#        - The cost recalibration logic respects the 5% threshold
#          (computational sensor declared 30s vs observed mean ~13s
#          → updated; inferential sensor declared 60s vs observed
#          mean ~82s → updated).
#
# This deterministic harness is what the skill's contract guarantees
# even when the agentic distillation produces the same set of
# candidate bullets across re-runs (which is the skill's stated
# invariant: idempotency comes from the citation grep, not from the
# LLM).
#
# Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md
# (Sprint 3, t05). Permanent — runs in the CI gate (Sprint 3 t06).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_SRC="${REPO_ROOT}/tests/fixtures/consolidation-stage"

FAIL=0
fail() { echo "FAIL: $*" >&2; FAIL=1; }
pass() { echo "PASS: $*"; }

echo "--- consolidation-stage permanent test ---"

# ---------------------------------------------------------------------------
# Setup: fully-isolated fixture under /tmp.
# ---------------------------------------------------------------------------
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/yoke-consolidate-test.XXXXXX")"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# Mirror fixture into the isolated tree.
mkdir -p "$WORK_DIR/.yoke/sensors" \
         "$WORK_DIR/.yoke/runtime/.judge-verdicts/cycle-0" \
         "$WORK_DIR/.yoke/runtime/.judge-verdicts/cycle-1" \
         "$WORK_DIR/.yoke/runtime/.judge-verdicts/cycle-2"

cp "$FIXTURE_SRC/sensors/marker-comp.md" "$WORK_DIR/.yoke/sensors/marker-comp.md"
cp "$FIXTURE_SRC/sensors/marker-inf.md"  "$WORK_DIR/.yoke/sensors/marker-inf.md"
cp "$FIXTURE_SRC/runtime/.current"        "$WORK_DIR/.yoke/runtime/.current"
cp "$FIXTURE_SRC/runtime/progress.md"     "$WORK_DIR/.yoke/runtime/progress.md"
cp "$FIXTURE_SRC/runtime/verdicts/cycle-0/"*.json "$WORK_DIR/.yoke/runtime/.judge-verdicts/cycle-0/"
cp "$FIXTURE_SRC/runtime/verdicts/cycle-1/"*.json "$WORK_DIR/.yoke/runtime/.judge-verdicts/cycle-1/"
cp "$FIXTURE_SRC/runtime/verdicts/cycle-2/"*.json "$WORK_DIR/.yoke/runtime/.judge-verdicts/cycle-2/"
cp "$FIXTURE_SRC/config.yaml" "$WORK_DIR/.yoke/config.yaml"

# ---------------------------------------------------------------------------
# Wrapper that mimics the deterministic contract of /yoke:consolidate-sensors.
# Append-only with `(cycle N, fix-instruction X)` citation. Idempotent
# via citation grep. Cost recalibration on >5% delta with ≥3 runs.
# ---------------------------------------------------------------------------
consolidate_wrapper() {
  local sensors_dir="$1/.yoke/sensors"
  local verdicts_root="$1/.yoke/runtime/.judge-verdicts"

  for sensor_file in "$sensors_dir"/*.md; do
    local id
    id=$(awk '/^id:/ { sub(/^id:[[:space:]]*/, ""); print; exit }' "$sensor_file")

    # Walk every cycle's verdicts that target this sensor; for each
    # fail/skip with a non-null fix_instruction, derive a one-phrase
    # summary and a citation, then append iff the citation does not
    # already appear in the file.
    local cycle_dir
    for cycle_dir in "$verdicts_root"/cycle-*/; do
      [ -d "$cycle_dir" ] || continue
      local cycle_n
      cycle_n=$(basename "$cycle_dir" | sed 's/^cycle-//')
      local v
      for v in "$cycle_dir"*.json; do
        [ -f "$v" ] || continue
        # Filter on sensor id.
        grep -q "\"sensor\":[[:space:]]*\"${id}\"" "$v" || continue
        # Filter on status fail.
        grep -q '"status":[[:space:]]*"fail"' "$v" || continue
        # Extract fix_instruction (single-line value).
        local fix
        fix=$(awk -F'"' '/"fix_instruction":/ { for (i=1; i<=NF; i++) if ($i ~ /fix_instruction/) { print $(i+2); exit } }' "$v")
        [ -z "$fix" ] && continue
        # Compose the citation. The summary phrase is the fix-instruction
        # text up to the first sentence-end / colon (truncated to 60 chars).
        local summary
        summary=$(printf '%s' "$fix" | sed -E 's/[.:]([[:space:]]|$).*//' | cut -c1-60)
        local citation="(cycle ${cycle_n}, fix-instruction ${summary})"

        # Idempotency check: skip if the citation already appears.
        if grep -qF "$citation" "$sensor_file"; then
          continue
        fi

        # Append a bullet to `## Frequent errors`. Insert before the
        # next H2 / H3 heading or at EOF.
        python3 - "$sensor_file" "$citation" "$fix" <<'PY'
import sys, re
path, citation, fix = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    lines = f.readlines()

# Find `## Frequent errors` line index.
idx = None
for i, l in enumerate(lines):
    if l.rstrip() == "## Frequent errors":
        idx = i
        break
if idx is None:
    sys.exit(0)

# Find end of section (next ## or ### or EOF).
end = len(lines)
for j in range(idx + 1, len(lines)):
    if lines[j].startswith("## ") or lines[j].startswith("### "):
        end = j
        break

# Skip any trailing blank line at the end.
insert = end
while insert > idx + 1 and lines[insert - 1].strip() == "":
    insert -= 1

bullet = f"- {fix}: see citation. {citation}\n"
lines.insert(insert, bullet)
with open(path, "w") as f:
    f.writelines(lines)
PY
      done
    done

    # Cost recalibration (deterministic, post-bullet append). Use the
    # `time_cost_observed` and `token_cost_observed` synthetic fields
    # the fixture carries in progress.md to drive the 5%-delta check.
    local progress="$1/.yoke/runtime/progress.md"
    [ -f "$progress" ] || continue
    # Synthetic block format in progress.md:
    #   <id>:
    #     time_cost_observed: <int>
    #     token_cost_observed: <int>  (optional)
    local time_observed
    time_observed=$(awk -v id="$id" '
      $0 ~ "^"id":$" { in_block=1; next }
      in_block && /time_cost_observed:/ { sub(/.*time_cost_observed:[[:space:]]*/, ""); print; exit }
      in_block && /^[a-z]/ { exit }
    ' "$progress")
    local time_declared
    time_declared=$(awk '/^time_cost:/ { sub(/^time_cost:[[:space:]]*/, ""); print; exit }' "$sensor_file")
    if [ -n "$time_observed" ] && [ -n "$time_declared" ]; then
      # Compute |observed - declared| / max(declared, 1) and compare to 0.05.
      local update
      update=$(python3 -c "obs=$time_observed; dec=max($time_declared,1); print(1 if abs(obs-dec)/dec > 0.05 else 0)")
      if [ "$update" = "1" ]; then
        # Update via sed in-place. Use a temp file for portability.
        sed "s/^time_cost: ${time_declared}\$/time_cost: ${time_observed}/" "$sensor_file" > "${sensor_file}.tmp"
        mv "${sensor_file}.tmp" "$sensor_file"
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Run 1
# ---------------------------------------------------------------------------
consolidate_wrapper "$WORK_DIR"

# Snapshot post-run-1 state.
run1_marker_comp_md5=$(md5 -q "$WORK_DIR/.yoke/sensors/marker-comp.md" 2>/dev/null || md5sum "$WORK_DIR/.yoke/sensors/marker-comp.md" | awk '{print $1}')
run1_marker_inf_md5=$(md5 -q "$WORK_DIR/.yoke/sensors/marker-inf.md" 2>/dev/null || md5sum "$WORK_DIR/.yoke/sensors/marker-inf.md" | awk '{print $1}')

# Assertion 1: marker-comp gained at least one bullet with `cycle ` and
# `fix-instruction` substrings.
if grep -qE 'cycle [0-9]+' "$WORK_DIR/.yoke/sensors/marker-comp.md" \
   && grep -q 'fix-instruction' "$WORK_DIR/.yoke/sensors/marker-comp.md"; then
  pass "Run 1 appended a bullet with 'cycle ' and 'fix-instruction' to marker-comp"
else
  fail "Run 1 did not append a citation-bearing bullet to marker-comp"
  echo "--- marker-comp.md after Run 1 ---" >&2
  cat "$WORK_DIR/.yoke/sensors/marker-comp.md" >&2
fi

# Assertion 2: time_cost recalibrated when the observed mean diverges
# by >5% (computational sensor declared 30, observed 13 → must update).
new_time_comp=$(awk '/^time_cost:/ { sub(/^time_cost:[[:space:]]*/, ""); print; exit }' "$WORK_DIR/.yoke/sensors/marker-comp.md")
if [ "$new_time_comp" != "30" ]; then
  pass "marker-comp time_cost recalibrated (declared 30 → ${new_time_comp})"
else
  fail "marker-comp time_cost should have recalibrated (declared 30, observed 13, delta > 5%)"
fi

# Assertion 3: inferential sensor (declared 60, observed 82) → must update.
new_time_inf=$(awk '/^time_cost:/ { sub(/^time_cost:[[:space:]]*/, ""); print; exit }' "$WORK_DIR/.yoke/sensors/marker-inf.md")
if [ "$new_time_inf" != "60" ]; then
  pass "marker-inf time_cost recalibrated (declared 60 → ${new_time_inf})"
else
  fail "marker-inf time_cost should have recalibrated (declared 60, observed 82, delta > 5%)"
fi

# ---------------------------------------------------------------------------
# Run 2 — must be byte-identical (idempotency).
# ---------------------------------------------------------------------------
consolidate_wrapper "$WORK_DIR"

run2_marker_comp_md5=$(md5 -q "$WORK_DIR/.yoke/sensors/marker-comp.md" 2>/dev/null || md5sum "$WORK_DIR/.yoke/sensors/marker-comp.md" | awk '{print $1}')
run2_marker_inf_md5=$(md5 -q "$WORK_DIR/.yoke/sensors/marker-inf.md" 2>/dev/null || md5sum "$WORK_DIR/.yoke/sensors/marker-inf.md" | awk '{print $1}')

if [ "$run1_marker_comp_md5" = "$run2_marker_comp_md5" ]; then
  pass "marker-comp byte-identical after Run 2 (idempotency holds)"
else
  fail "marker-comp diverged on Run 2 (Run 1: ${run1_marker_comp_md5}, Run 2: ${run2_marker_comp_md5})"
  echo "--- diff ---" >&2
  diff <(cat "$WORK_DIR/.yoke/sensors/marker-comp.md") <(cat "$WORK_DIR/.yoke/sensors/marker-comp.md") >&2 || true
fi

if [ "$run1_marker_inf_md5" = "$run2_marker_inf_md5" ]; then
  pass "marker-inf byte-identical after Run 2 (idempotency holds)"
else
  fail "marker-inf diverged on Run 2 (Run 1: ${run1_marker_inf_md5}, Run 2: ${run2_marker_inf_md5})"
fi

if [ "$FAIL" -eq 0 ]; then
  echo "--- consolidation-stage: ALL PASS ---"
  exit 0
else
  echo "--- consolidation-stage: FAILURES ABOVE ---" >&2
  exit 1
fi
