#!/usr/bin/env bash
# tests/ralph-loop-bounds.test.sh
#
# Ralph-loop hard bounds:
#   (a) hooks/check-hard-bounds.sh is executable
#   (b) given synthetic state with cycle count exceeding the configured
#       bound, the hook exits non-zero (10 per its contract)
#   (c) the exit-output contains structured "bound reached" identification
#       (sensor schema, not a generic message)
#   (d) lib/ralph-loop/escalate.sh exists and references Trigger 4
#
# No real ralph-loop execution. Synthetic state is created in mktemp.

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (a) Executable
# ---------------------------------------------------------------------
if [ -x hooks/check-hard-bounds.sh ]; then
  pass "(a) hooks/check-hard-bounds.sh is executable"
else
  err "(a) hooks/check-hard-bounds.sh not executable"
fi

# ---------------------------------------------------------------------
# (b, c) Synthetic over-bound state — hook exits 10 with structured output
# ---------------------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

(
  cd "$TMP"
  mkdir -p .yoke/runtime

  cat > .yoke/config.yaml <<'YAML'
overrides:
  hard_bounds:
    cycles_max: 1
    timeout_seconds: 14400
    token_budget: 200000
YAML

  echo 5 > .yoke/runtime/.cycle-counter
  date +%s > .yoke/runtime/.loop-start
  echo 0 > .yoke/runtime/.token-budget-used
)

bounds_out=""
bounds_exit=0
bounds_out=$(cd "$TMP" && bash "$PLUGIN_ROOT/hooks/check-hard-bounds.sh" 2>&1) \
  || bounds_exit=$?

if [ "$bounds_exit" -eq 10 ]; then
  pass "(b) check-hard-bounds.sh exits 10 on synthetic over-bound state"
else
  err "(b) check-hard-bounds.sh exit_code=$bounds_exit (expected 10)"
fi

# Structured-output schema: Trigger-4 packet has `reason:`, `cycles:`,
# `cycles_max:`, etc. plus a `Hard bound reached:` line.
if echo "$bounds_out" | grep -qE 'reason:[[:space:]]*hard-bound' \
  && echo "$bounds_out" | grep -qE 'cycles:[[:space:]]*[0-9]+' \
  && echo "$bounds_out" | grep -qE '^Hard bound reached: cycles'; then
  pass "(c) check-hard-bounds.sh emits structured bound-reached identification"
else
  err "(c) check-hard-bounds.sh output is not structured per Trigger-4 schema"
fi

# ---------------------------------------------------------------------
# (d) escalate.sh exists and references Trigger 4
# ---------------------------------------------------------------------
if [ -f lib/ralph-loop/escalate.sh ]; then
  pass "(d) lib/ralph-loop/escalate.sh present"
else
  err "(d) lib/ralph-loop/escalate.sh missing"
fi

if grep -qE 'Trigger.4|Trigger-4|trigger4|trigger:[[:space:]]*4' lib/ralph-loop/escalate.sh; then
  pass "(d) escalate.sh references Trigger 4"
else
  err "(d) escalate.sh missing Trigger 4 reference"
fi

# ---------------------------------------------------------------------
# (e) Background spawning — per-cycle Generator/Validator/Orchestrator
#     batch declares run_in_background: true; canonize handoff stays
#     foreground.
# ---------------------------------------------------------------------
skill_md="skills/implement/SKILL.md"

if [ -f "$skill_md" ]; then
  pass "(e) skills/implement/SKILL.md present"
else
  err "(e) skills/implement/SKILL.md missing"
fi

# Per-cycle batch section (between "Concurrent subagent batch" header
# and "Phase B — council loop" header) declares run_in_background: true.
# v3.0 council protocol replaces "Concurrent subagent batch" with Phase A.
batch_section=$(awk '/Phase A — parallel persona spawn/,/Phase B — council loop/' "$skill_md")
if echo "$batch_section" | grep -qE 'run_in_background:[[:space:]]*true'; then
  pass "(e) per-cycle Phase A batch declares run_in_background: true"
else
  err "(e) per-cycle Phase A batch missing run_in_background: true directive"
fi

# Termination canonize handoff (between "Termination handoff" header
# and "Sensor consolidation teardown" header) does NOT declare
# run_in_background: true — the canonize call is foreground.
canonize_section=$(awk '/Termination handoff/,/Sensor consolidation teardown/' "$skill_md")
if echo "$canonize_section" | grep -qE 'run_in_background:[[:space:]]*true'; then
  err "(e) canonize handoff incorrectly uses run_in_background: true"
else
  pass "(e) canonize handoff stays foreground (no run_in_background:true)"
fi

# ---------------------------------------------------------------------
# (f) Cycle status snapshot — helper exists, SKILL.md invokes it once
#     per cycle, output template references the required field labels.
# ---------------------------------------------------------------------
snapshot_helper="lib/ralph-loop/status-snapshot.sh"

if [ -x "$snapshot_helper" ]; then
  pass "(f) lib/ralph-loop/status-snapshot.sh exists and is executable"
else
  err "(f) lib/ralph-loop/status-snapshot.sh missing or not executable"
fi

# SKILL.md invokes the helper exactly once inside the cycle-loop body
# (between "For each cycle" and the "Termination handoff" heading).
cycle_body=$(awk '/^For each cycle/,/^### 3\. Termination handoff/' "$skill_md")
helper_invocations=$(printf '%s\n' "$cycle_body" \
  | grep -cE 'lib/ralph-loop/status-snapshot\.sh' \
  || true)
if [ "$helper_invocations" -eq 1 ]; then
  pass "(f) SKILL.md invokes status-snapshot.sh exactly once per cycle"
else
  err "(f) SKILL.md status-snapshot.sh invocation count = $helper_invocations (expected 1)"
fi

# Helper output template references every field enumerated in DoD #3:
# Cycle number, Generator/Validator/Orchestrator labels, judge: prefix,
# Sensors line (with computational + inferential), Bounds line (with
# cycles + elapsed).
required_labels=(
  'Cycle '
  '- Generator:'
  '- Validator:'
  '- Orchestrator:'
  '- judge:'
  'Sensors:'
  'computational'
  'inferential'
  'Bounds:'
  'cycles'
  'elapsed'
)
for label in "${required_labels[@]}"; do
  if grep -qF -- "$label" "$snapshot_helper"; then
    pass "(f) status-snapshot.sh template references: $label"
  else
    err "(f) status-snapshot.sh template missing: $label"
  fi
done

# Integration smoke — run the helper against a synthetic runtime.
SS_TMP=$(mktemp -d)
mkdir -p "$SS_TMP/runtime/.snapshots" "$SS_TMP/runtime/.judge-verdicts/cycle-3"
echo 3 > "$SS_TMP/runtime/.cycle-counter"
echo $(($(date +%s) - 42)) > "$SS_TMP/runtime/.loop-start"
cat > "$SS_TMP/runtime/.snapshots/cycle-3.yaml" <<'YAML'
results:
  - sensor: ruff
    status: pass
    exit_code: 0
  - sensor: mypy
    status: fail
    exit_code: 1
YAML
# Verdict files use the (criterion, sensor) keying introduced by the
# Part 2 cleanup — basename `<criterion>--<sensor>.json` so multiple
# sensors per criterion don't collide.
printf '%s\n' \
  '{"criterion":"FR-1","status":"pass","sensor":"voice","evidence":"x"}' \
  > "$SS_TMP/runtime/.judge-verdicts/cycle-3/FR-1--voice.json"
echo "FR-2--api" > "$SS_TMP/runtime/.judge-verdicts/cycle-3/.failures.log"

ss_out=$(bash "$snapshot_helper" "$SS_TMP/runtime" 2>&1)
ss_exit=$?
rm -rf "$SS_TMP"

if [ "$ss_exit" -eq 0 ]; then
  pass "(f) status-snapshot.sh exits 0 on synthetic input"
else
  err "(f) status-snapshot.sh exit_code=$ss_exit (expected 0)"
fi

if echo "$ss_out" | grep -qE '^### Cycle 3 ' \
  && echo "$ss_out" | grep -q '^- Generator:' \
  && echo "$ss_out" | grep -q '^- judge:FR-1--voice: done' \
  && echo "$ss_out" | grep -q '^- judge:FR-2--api: failed' \
  && echo "$ss_out" | grep -qE '^Sensors: 1/1/0 computational' \
  && echo "$ss_out" | grep -qE '^Bounds:[[:space:]]+3/'; then
  pass "(f) status-snapshot.sh emits structured block with cycle/agent/sensor/bounds"
else
  err "(f) status-snapshot.sh output malformed:
$ss_out"
fi

harness::summary
