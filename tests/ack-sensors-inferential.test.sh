#!/bin/bash
# tests/ack-sensors-inferential.test.sh
#
# Part 3 smoke test — reconciled with main's coordinator-runs-once
# architecture. Original Part 3 had the Validator spawn each inferential
# sensor via Agent(subagent_type: yoke:semantic-judge); main's runtime
# restricts the Validator to invoking only /yoke:search-canonical-memory via the Skill tool.
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

# Promotion path: /yoke:canonize, not automatic
grep -q '/yoke:canonize' "$JUDGE" \
  && pass "judge documents /yoke:canonize promotion path" \
  || err "judge does not document /yoke:canonize"

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
# Skill-owned inferential-sensor spawning (runtime-background-agents Part 2)
# ---------------------------------------------------------------------------
SKILL_IMPLEMENT="${PLUGIN_ROOT}/skills/implement/SKILL.md"
PATHS_LIB="${PLUGIN_ROOT}/lib/working-memory/paths.sh"

# (a) agents/validator.md does NOT contain a `subagent_type:` line —
# the Validator never spawns judges; spawn is owned by /yoke:implement.
if grep -qE '^[[:space:]]*subagent_type[[:space:]]*:' "$VALIDATOR"; then
  err "validator.md contains subagent_type — Validator must not spawn judges"
else
  pass "validator.md has no subagent_type (judge spawn owned by /yoke:implement)"
fi

# (b) skills/implement/SKILL.md describes skill-owned inferential-sensor
# spawning — references subagent_type: semantic-judge inside the
# per-cycle batch section.
if [ ! -f "$SKILL_IMPLEMENT" ]; then
  err "skills/implement/SKILL.md missing"
else
  batch_section=$(awk '/Concurrent subagent batch/,/Sensor execution/' "$SKILL_IMPLEMENT")
  if echo "$batch_section" | grep -qE 'subagent_type:[[:space:]]*semantic-judge'; then
    pass "SKILL.md per-cycle batch declares subagent_type: semantic-judge"
  else
    err "SKILL.md per-cycle batch missing subagent_type: semantic-judge"
  fi

  # Per-cycle batch width is 3 + N (not just 3).
  if echo "$batch_section" | grep -qE '3[[:space:]]*\+[[:space:]]*N'; then
    pass "SKILL.md per-cycle batch advertises width 3 + N"
  else
    err "SKILL.md per-cycle batch missing 3 + N width directive"
  fi

  # Concurrency cap config key documented.
  if grep -qE 'runtime\.inferential_sensor_concurrency' "$SKILL_IMPLEMENT"; then
    pass "SKILL.md documents runtime.inferential_sensor_concurrency cap"
  else
    err "SKILL.md missing runtime.inferential_sensor_concurrency cap"
  fi

  # Anti-pattern: no judge spawning from inside subagents.
  if grep -qE 'Do NOT spawn `?semantic-judge`?' "$SKILL_IMPLEMENT"; then
    pass "SKILL.md anti-pattern forbids semantic-judge spawn from subagents"
  else
    err "SKILL.md missing semantic-judge spawn-prohibition anti-pattern"
  fi
fi

# (c) lib/working-memory/paths.sh defines the verdict path helpers.
if [ ! -f "$PATHS_LIB" ]; then
  err "lib/working-memory/paths.sh missing"
else
  if grep -qE '^wm_judge_verdict_dir\(\)' "$PATHS_LIB"; then
    pass "paths.sh defines wm_judge_verdict_dir()"
  else
    err "paths.sh missing wm_judge_verdict_dir()"
  fi
  if grep -qE '^wm_judge_verdict_path\(\)' "$PATHS_LIB"; then
    pass "paths.sh defines wm_judge_verdict_path()"
  else
    err "paths.sh missing wm_judge_verdict_path()"
  fi

  # Smoke: the helpers actually echo the documented path. The wm_*
  # family uses printf without trailing newline, so capture each
  # invocation in its own subshell and compare exactly.
  helper_tmp=$(mktemp -d)
  mkdir -p "$helper_tmp/.yoke/runtime"
  echo 2026-04-26-test-slug > "$helper_tmp/.yoke/runtime/.current"
  dir_actual=$(
    cd "$helper_tmp" \
      && bash -c "source \"$PATHS_LIB\" && wm_judge_verdict_dir 2026-04-26-test-slug 3" 2>&1
  )
  # wm_judge_verdict_path is keyed by (criterion, sensor) so every
  # inferential sensor mapped to the same criterion gets a distinct
  # filename — supports patterns/sensors.md any-fail-wins aggregation.
  path_actual=$(
    cd "$helper_tmp" \
      && bash -c "source \"$PATHS_LIB\" && wm_judge_verdict_path 2026-04-26-test-slug 3 FR-1 voice" 2>&1
  )
  # Sanitization smoke: a sensor id with `/` becomes `_` in the
  # basename so the path is filesystem-safe.
  path_sanitized=$(
    cd "$helper_tmp" \
      && bash -c "source \"$PATHS_LIB\" && wm_judge_verdict_path 2026-04-26-test-slug 3 FR-2 'semantic-judge/voice'" 2>&1
  )
  # Missing-sensor invocation must fail with a clear message.
  set +e
  missing_sensor_out=$(
    cd "$helper_tmp" \
      && bash -c "source \"$PATHS_LIB\" && wm_judge_verdict_path 2026-04-26-test-slug 3 FR-1" 2>&1
  )
  missing_sensor_exit=$?
  set -e
  rm -rf "$helper_tmp"
  if [ "$dir_actual" = ".yoke/runtime/.judge-verdicts/cycle-3" ] \
    && [ "$path_actual" = ".yoke/runtime/.judge-verdicts/cycle-3/FR-1--voice.json" ] \
    && [ "$path_sanitized" = ".yoke/runtime/.judge-verdicts/cycle-3/FR-2--semantic-judge_voice.json" ]; then
    pass "paths.sh helpers emit (criterion, sensor)-keyed verdict paths"
  else
    err "paths.sh helpers emit unexpected output: dir='$dir_actual' path='$path_actual' sanitized='$path_sanitized'"
  fi
  if [ "$missing_sensor_exit" -ne 0 ] \
    && echo "$missing_sensor_out" | grep -qE '<sensor-id>'; then
    pass "paths.sh wm_judge_verdict_path rejects missing sensor arg with structured error"
  else
    err "paths.sh wm_judge_verdict_path missing-sensor handling broken: exit=$missing_sensor_exit out='$missing_sensor_out'"
  fi
fi

# Validator agent reads from .judge-verdicts/cycle-<N-1>/.
if grep -qE '\.judge-verdicts' "$VALIDATOR"; then
  pass "validator.md references .judge-verdicts as inferential input"
else
  err "validator.md does not reference .judge-verdicts"
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
