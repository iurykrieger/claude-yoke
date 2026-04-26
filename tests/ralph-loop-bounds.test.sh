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

harness::summary
