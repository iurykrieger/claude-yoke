#!/bin/bash
# tests/ack-sensors-inferential.test.sh
#
# Part 3 smoke test — reconciled with main's coordinator-runs-once
# architecture. Original Part 3 had the Validator spawn each inferential
# sensor via Agent(subagent_type: yoke:semantic-judge); main's runtime
# restricts the Validator to invoking only /yoke:ask via the Skill tool.
#
# Under the post-merge architecture, the semantic-judge subagent and its
# template are forward-looking artifacts: the calibration metadata, prompt
# skeleton, and verdict shape stand on their own. Whichever runtime
# component eventually drives inferential evaluation will spawn this
# subagent — under main today, that integration is deferred.
#
# This smoke test verifies what survives the reconciliation:
#   - lib/sensors/templates/semantic-judge.md ships with mandatory
#     calibration frontmatter
#   - agents/semantic-judge.md has strict Read-only context isolation
#   - Verdict shape parity (canonical six keys) between Validator and
#     judge

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="${PLUGIN_ROOT}/lib/sensors/templates/semantic-judge.md"
JUDGE="${PLUGIN_ROOT}/agents/semantic-judge.md"
VALIDATOR="${PLUGIN_ROOT}/agents/validator.md"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- ack-sensors Part 3 smoke (reconciled) ---"

[ -f "$TEMPLATE"  ] || { err "missing template: $TEMPLATE"; exit 1; }
[ -f "$JUDGE"     ] || { err "missing subagent: $JUDGE";    exit 1; }
[ -f "$VALIDATOR" ] || { err "missing validator: $VALIDATOR"; exit 1; }

# ---------------------------------------------------------------------------
# DoD #1 — semantic-judge template ships with calibration frontmatter
# ---------------------------------------------------------------------------
for field in 'template:' 'class:' 'calibrated_against:' 'calibrated_at:' \
             'known_false_positives:' 'known_false_negatives:' \
             'criterion_scope:' 'default_timeout_seconds:'; do
  if awk '/^---$/{c++} c==1' "$TEMPLATE" | grep -q "^${field}"; then
    pass "template frontmatter has: ${field}"
  else
    err "template frontmatter missing: ${field}"
  fi
done

# class must be 'inferential'
class_value=$(awk '/^---$/{c++; next} c==1 && /^class:/{print $2; exit}' "$TEMPLATE" || true)
if [ "$class_value" = "inferential" ]; then
  pass "template class = inferential"
else
  err "template class = '$class_value' (expected inferential)"
fi

# default_timeout_seconds must be 120
default_timeout=$(awk '/^---$/{c++; next} c==1 && /^default_timeout_seconds:/{print $2; exit}' "$TEMPLATE" || true)
if [ "$default_timeout" = "120" ]; then
  pass "template default_timeout_seconds = 120"
else
  err "template default_timeout_seconds = '$default_timeout' (expected 120)"
fi

# Template must mention the prompt skeleton placeholders
for placeholder in '{{criterion}}' '{{diff}}' '{{calibration_block}}'; do
  grep -qF "$placeholder" "$TEMPLATE" \
    && pass "template prompt skeleton has: $placeholder" \
    || err "template missing placeholder: $placeholder"
done

# ---------------------------------------------------------------------------
# DoD #6 — semantic-judge subagent: tools = Read only
# ---------------------------------------------------------------------------
tools_line=$(awk '/^tools:/{print; exit}' "$JUDGE" || true)
if [ -z "$tools_line" ]; then
  err "judge frontmatter missing tools: field"
else
  tools_val="$(echo "$tools_line" | sed -E 's/^tools:[[:space:]]*//')"
  if [ "$tools_val" = "Read" ]; then
    pass "judge tools = Read only (strict context isolation)"
  else
    err "judge tools = '$tools_val' (expected exactly 'Read')"
  fi
fi

# Confirm forbidden tools NOT in the frontmatter line
for forbidden in 'Write' 'Edit' 'Bash' 'Grep' 'Glob' 'Agent' 'Task' 'Monitor'; do
  if echo "$tools_line" | grep -qw "$forbidden"; then
    err "judge tools includes forbidden: $forbidden"
  else
    pass "judge tools excludes forbidden: $forbidden"
  fi
done

# Judge must declare "name: semantic-judge"
awk '/^name:[[:space:]]*semantic-judge[[:space:]]*$/{found=1} END{exit found?0:1}' "$JUDGE" \
  && pass "judge name = semantic-judge" \
  || err "judge name is not 'semantic-judge'"

# Judge must explicitly forbid reading other working-memory files
for forbidden_read in 'progress.md' 'query-trace' 'contracts.md'; do
  if grep -q "$forbidden_read" "$JUDGE"; then
    pass "judge documents forbidden read: $forbidden_read"
  else
    err "judge does not forbid reading: $forbidden_read"
  fi
done

# Judge must reference canonical-memory write prohibition
grep -qiE 'never read or write canonical' "$JUDGE" \
  && pass "judge forbids canonical-memory access" \
  || err "judge does not forbid canonical-memory access"

# ---------------------------------------------------------------------------
# DoD #2 — Judge emits the same JSON verdict shape as computational
# ---------------------------------------------------------------------------
for key in 'criterion' 'status' 'location' 'fix_instruction' 'sensor' 'evidence'; do
  if grep -q "\"$key\":" "$JUDGE"; then
    pass "judge verdict shape includes: $key"
  else
    err "judge verdict shape missing: $key"
  fi
done

# DoD #7 — verdict shape parity asserted by checking same six keys appear
# in BOTH validator.md (computational verdict shape) AND judge.md.
for key in 'criterion' 'status' 'location' 'fix_instruction' 'sensor' 'evidence'; do
  v_has=$(grep -c "\"$key\":" "$VALIDATOR" || echo 0)
  j_has=$(grep -c "\"$key\":" "$JUDGE" || echo 0)
  if [ "$v_has" -gt 0 ] && [ "$j_has" -gt 0 ]; then
    pass "verdict shape parity (Validator ↔ judge): $key"
  else
    err "verdict shape parity broken for: $key (validator=$v_has, judge=$j_has)"
  fi
done

# ---------------------------------------------------------------------------
# DoD #5 — Calibration drift writes to .yoke/sensors/<name>.md only
# (template + judge documentation; runtime wiring is post-merge follow-up)
# ---------------------------------------------------------------------------
grep -q '\.yoke/sensors/' "$JUDGE" \
  && pass "judge references .yoke/sensors/ as drift target" \
  || err "judge does not reference .yoke/sensors/"

grep -q '\.yoke/sensors/' "$TEMPLATE" \
  && pass "template documents .yoke/sensors/ drift contract" \
  || err "template does not document .yoke/sensors/"

# Promotion path: /yoke:preserve, not automatic
grep -q '/yoke:preserve' "$JUDGE" \
  && pass "judge documents /yoke:preserve promotion path" \
  || err "judge does not document /yoke:preserve"

# ---------------------------------------------------------------------------
# DoD #5 (no canonical-memory writes from this part)
# ---------------------------------------------------------------------------
for f in "$TEMPLATE" "$JUDGE"; do
  if grep -q 'propose-write' "$f"; then
    err "$(basename "$f") references propose-write — must NOT write canonical memory"
  else
    pass "$(basename "$f") does not call propose-write (canonical-memory boundary preserved)"
  fi
done

# ---------------------------------------------------------------------------
# Subagent context-isolation contract: judge gets exactly three inputs
# ---------------------------------------------------------------------------
for input in 'criterion' 'diff'; do
  if grep -q "$input" "$JUDGE"; then
    pass "judge documents spawn input: $input"
  else
    err "judge missing spawn input documentation: $input"
  fi
done

if grep -qE 'calibration[ _]block' "$JUDGE"; then
  pass "judge documents spawn input: calibration_block / calibration block"
else
  err "judge missing spawn input documentation: calibration_block"
fi

# ---------------------------------------------------------------------------
# Regression — Parts 1 + 2 still pass
# ---------------------------------------------------------------------------
if bash "${PLUGIN_ROOT}/tests/ack-sensors-catalog.test.sh" >/dev/null 2>&1; then
  pass "Part 1 catalog smoke still passes"
else
  err "Part 1 catalog smoke regressed!"
fi

if bash "${PLUGIN_ROOT}/tests/ack-sensors-parallel.test.sh" >/dev/null 2>&1; then
  pass "Part 2 parallel smoke still passes"
else
  err "Part 2 parallel smoke regressed!"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "--- ack-sensors Part 3 smoke (reconciled): ${fail} failure(s) ---"
exit "$fail"
