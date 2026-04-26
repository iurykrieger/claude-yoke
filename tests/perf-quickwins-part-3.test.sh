#!/bin/bash
# tests/perf-quickwins-part-3.test.sh
#
# Smoke test for Part 3 of the runtime perf-quickwins (tiered model
# pinning). Verifies the *wiring* of per-role model resolution; the
# actual LLM-output regression against fixture-vs-reference verdicts
# is a deployment-time gate that requires invoking Claude — see the
# "deferred-llm-check" note below.
#
# Static checks performed here:
#   1. lib/runtime/agent-config.sh exists, sources cleanly, exposes
#      yoke_resolve_model + yoke_log_resolved_models.
#   2. Defaults match the spec:
#        validator                → claude-sonnet-4-6
#        orchestrator.consult     → claude-sonnet-4-6
#        orchestrator.monitor     → claude-sonnet-4-6
#        generator                → "" (inherit session model)
#        orchestrator.canonize    → "" (inherit session model)
#   3. Overrides in .yoke/config.yaml are respected for both flat keys
#      (validator) and nested orchestrator.<mode> keys.
#   4. yoke_log_resolved_models writes [task-spawn] role=<r> model=<m>
#      lines to the trace file (R2 mitigation: pinning provenance).
#   5. R4 canonize-leak gate: when consult is overridden but canonize
#      is left to default, canonize MUST NOT pick up the consult value.
#   6. templates/yoke-config.yaml documents the runtime.models block
#      (DoD #4) with all five required keys.
#   7. skills/implement/SKILL.md sources the helper at preflight,
#      passes per-role model: arg per Task call, and uses
#      orch_canonize_model at termination (DoD #1, R4 gate).
#   8. agents/validator.md + agents/orchestrator.md persona/mode
#      sections reference the coordinator-pinned mechanism.
#   9. Fixture set (snapshots + expected-verdicts.json) exists with
#      the JSON shape the deployment-time gate consumes (DoD #5).
#
# Self-imposed 600s watchdog (per .vibeflow/conventions.md).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- perf-quickwins-part-3 smoke ---"

tmpdir="$(mktemp -d)"
# 600s watchdog. Redirect stdin/stdout/stderr to /dev/null so the
# subshell does NOT hold the script's stdout open after the trap fires.
( exec </dev/null >/dev/null 2>&1; sleep 600 && kill -TERM $$ 2>/dev/null ) &
watchdog_pid=$!
trap 'pkill -P "$watchdog_pid" 2>/dev/null || true; kill "$watchdog_pid" 2>/dev/null || true; rm -rf "$tmpdir"' EXIT

# ------------------------------------------------------------------
# 1. Helper exists and sources cleanly
# ------------------------------------------------------------------
helper="lib/runtime/agent-config.sh"
[ -f "$helper" ] || { err "missing $helper"; exit 1; }

# Source in a subshell to confirm idempotency + clean syntax
( source "$helper" && type yoke_resolve_model > /dev/null 2>&1 ) \
  && pass "(1) lib/runtime/agent-config.sh sources, yoke_resolve_model defined" \
  || err "(1) helper failed to source or yoke_resolve_model missing"

( source "$helper" && type yoke_log_resolved_models > /dev/null 2>&1 ) \
  && pass "(1) helper exposes yoke_log_resolved_models" \
  || err "(1) helper missing yoke_log_resolved_models"

# Idempotent re-source
( source "$helper" && source "$helper" ) \
  && pass "(1) helper re-source is idempotent" \
  || err "(1) helper not idempotent on re-source"

# ------------------------------------------------------------------
# 2. Defaults match the spec
# ------------------------------------------------------------------
# shellcheck disable=SC1091
source "$helper"

# Use a non-existent config path so only defaults apply
no_config="$tmpdir/missing.yaml"

for role in validator orchestrator.consult orchestrator.monitor; do
  v="$(yoke_resolve_model "$role" "$no_config")"
  if [ "$v" = "claude-sonnet-4-6" ]; then
    pass "(2) default model for $role = claude-sonnet-4-6"
  else
    err "(2) default model for $role = '$v', expected claude-sonnet-4-6"
  fi
done

for role in generator orchestrator.canonize default; do
  v="$(yoke_resolve_model "$role" "$no_config")"
  if [ -z "$v" ]; then
    pass "(2) default model for $role is empty (inherit session)"
  else
    err "(2) default model for $role = '$v', expected empty"
  fi
done

# ------------------------------------------------------------------
# 3. .yoke/config.yaml overrides
# ------------------------------------------------------------------
cfg="$tmpdir/config.yaml"
cat > "$cfg" <<'EOF'
yoke_version: "0.7.0"
runtime:
  models:
    default: claude-opus-4-7
    generator: claude-opus-4-7
    validator: claude-haiku-4-5
    orchestrator:
      consult: claude-haiku-4-5
      monitor: claude-haiku-4-5
      canonize: claude-opus-4-7
EOF

declare -A expected=(
  [generator]="claude-opus-4-7"
  [validator]="claude-haiku-4-5"
  [orchestrator.consult]="claude-haiku-4-5"
  [orchestrator.monitor]="claude-haiku-4-5"
  [orchestrator.canonize]="claude-opus-4-7"
  [default]="claude-opus-4-7"
)

for role in "${!expected[@]}"; do
  exp="${expected[$role]}"
  got="$(yoke_resolve_model "$role" "$cfg")"
  if [ "$got" = "$exp" ]; then
    pass "(3) override resolves: $role = $got"
  else
    err "(3) override misresolved: $role got '$got', expected '$exp'"
  fi
done

# ------------------------------------------------------------------
# 4. yoke_log_resolved_models writes [task-spawn] lines
# ------------------------------------------------------------------
trace="$tmpdir/query-trace.md"
yoke_log_resolved_models "$trace" "$cfg"

[ -f "$trace" ] && pass "(4) yoke_log_resolved_models created trace file" \
  || err "(4) trace file not created"

for role in generator validator orchestrator.consult orchestrator.monitor orchestrator.canonize; do
  if grep -qE "^\[task-spawn\] role=${role} model=" "$trace"; then
    pass "(4) trace contains [task-spawn] for $role"
  else
    err "(4) trace missing [task-spawn] for $role"
  fi
done

# ------------------------------------------------------------------
# 5. R4 canonize-leak gate.
# Override consult only; canonize must remain top-tier (here: empty
# default since `default:` is not set in the partial config).
# ------------------------------------------------------------------
cfg2="$tmpdir/config-partial.yaml"
cat > "$cfg2" <<'EOF'
runtime:
  models:
    orchestrator:
      consult: claude-haiku-4-5
EOF

leak_consult="$(yoke_resolve_model orchestrator.consult "$cfg2")"
leak_canonize="$(yoke_resolve_model orchestrator.canonize "$cfg2")"

if [ "$leak_consult" = "claude-haiku-4-5" ]; then
  pass "(5) R4 setup: consult correctly picked up haiku override"
else
  err "(5) R4 setup: consult expected haiku, got '$leak_consult'"
fi

if [ -z "$leak_canonize" ]; then
  pass "(5) R4 gate: canonize did NOT leak the consult override (empty = inherit session)"
else
  if [ "$leak_canonize" = "claude-haiku-4-5" ]; then
    err "(5) R4 LEAK: canonize picked up the consult override = '$leak_canonize'"
  else
    pass "(5) R4 gate: canonize resolved to '$leak_canonize' (not the consult value)"
  fi
fi

# ------------------------------------------------------------------
# 6. templates/yoke-config.yaml exposes runtime.models block
# ------------------------------------------------------------------
tmpl="templates/yoke-config.yaml"
[ -f "$tmpl" ] || { err "(6) missing $tmpl"; }

for key in \
  "runtime:" \
  "models:" \
  "default:" \
  "validator:" \
  "orchestrator:" \
  "consult:" \
  "monitor:" \
  "canonize:"; do
  if grep -qF "$key" "$tmpl"; then
    pass "(6) yoke-config.yaml documents '$key'"
  else
    err "(6) yoke-config.yaml missing '$key'"
  fi
done

# Sonnet 4.6 + opus 4.7 identifiers documented
for id in claude-sonnet-4-6 claude-opus-4-7; do
  if grep -qF "$id" "$tmpl"; then
    pass "(6) yoke-config.yaml documents identifier '$id'"
  else
    err "(6) yoke-config.yaml missing identifier '$id'"
  fi
done

# ------------------------------------------------------------------
# 7. skills/implement/SKILL.md wires per-Task model: arg
# ------------------------------------------------------------------
sk="skills/implement/SKILL.md"

if grep -qF "lib/runtime/agent-config.sh" "$sk"; then
  pass "(7) SKILL.md sources lib/runtime/agent-config.sh"
else
  err "(7) SKILL.md does NOT source lib/runtime/agent-config.sh"
fi

for var in generator_model validator_model orch_consult_model orch_canonize_model; do
  if grep -qF "$var" "$sk"; then
    pass "(7) SKILL.md references \$$var"
  else
    err "(7) SKILL.md missing reference to \$$var"
  fi
done

if grep -qF 'yoke_log_resolved_models' "$sk"; then
  pass "(7) SKILL.md logs resolved models to query trace (R2 verification)"
else
  err "(7) SKILL.md does NOT call yoke_log_resolved_models"
fi

# R4 wiring: termination handoff explicitly references canonize model
if grep -qE 'mode=canonize.*orch_canonize_model|orch_canonize_model.*mode=canonize|orch_canonize_model' "$sk" \
   && awk '
       /^### 3\. Termination handoff/,/^### 4\./ {
         if (/orch_canonize_model/) found = 1
       }
       END { exit found ? 0 : 1 }
     ' "$sk"; then
  pass "(7) SKILL.md §3 termination handoff uses \$orch_canonize_model (R4 gate)"
else
  err "(7) SKILL.md §3 termination handoff does NOT explicitly use \$orch_canonize_model"
fi

# ------------------------------------------------------------------
# 8. agents/validator.md + agents/orchestrator.md persona comments
# ------------------------------------------------------------------
val="agents/validator.md"
orc="agents/orchestrator.md"

if grep -qF "Model selection" "$val" && grep -qF "yoke_resolve_model validator" "$val"; then
  pass "(8) validator.md persona references coordinator-pinned model mechanism"
else
  err "(8) validator.md persona missing model-selection comment"
fi

if grep -qF "Model selection" "$orc" \
   && grep -qF "orchestrator.consult" "$orc" \
   && grep -qF "orchestrator.canonize" "$orc"; then
  pass "(8) orchestrator.md mode-declaration references per-mode pinning"
else
  err "(8) orchestrator.md mode-declaration missing per-mode pinning comment"
fi

# Anti-scope: orchestrator's sole-canonical-memory-writer authority preserved
if grep -qF "sole writer of canonical memory" "$orc"; then
  pass "(8) orchestrator.md preserves sole-canonical-memory-writer authority"
else
  err "(8) orchestrator.md authority weakened"
fi

# ------------------------------------------------------------------
# 9. Fixture + reference verdict file (DoD #5)
# ------------------------------------------------------------------
fixdir="tests/fixtures/perf-quickwins-part-3"
[ -d "$fixdir/snapshots" ] && pass "(9) fixture snapshots/ dir exists" \
  || err "(9) fixture snapshots/ dir missing"

snap_count=$(find "$fixdir/snapshots" -maxdepth 1 -name '*.yaml' | wc -l | tr -d ' ')
if [ "$snap_count" -ge 1 ]; then
  pass "(9) fixture snapshots/ has $snap_count snapshot(s)"
else
  err "(9) fixture snapshots/ has 0 snapshots"
fi

ref="$fixdir/expected-verdicts.json"
[ -f "$ref" ] && pass "(9) reference verdicts file exists" \
  || err "(9) $ref missing"

# JSON shape sanity (no jq dependency — grep on required keys)
for key in "calibrated_against" "calibrated_at" "verdicts" "criterion" "status" "sensor" "location" "fix_instruction" "evidence"; do
  if grep -qF "\"$key\"" "$ref"; then
    pass "(9) reference verdicts include '$key' field"
  else
    err "(9) reference verdicts missing '$key' field"
  fi
done

# Deployment-time-gate marker present
if grep -qE "deployment-time gate|claude code" "$ref"; then
  pass "(9) reference verdicts document the deployment-time gate"
else
  err "(9) reference verdicts missing deployment-time gate documentation"
fi

# ------------------------------------------------------------------
# 10. Anti-scope sanity (Generator + Canonize stay top-tier)
# ------------------------------------------------------------------
# Generator default empty (inherit session) — already checked in (2).
# Canonize default empty — already checked in (2) + (5).
# Confirm helper does NOT hard-code Sonnet for generator/canonize:
sonnet_in_gen=$(awk '
  /case[[:space:]]+"\$role"/ { in_case = 1 }
  in_case && /generator\|orchestrator\.canonize\|default/ { found_branch = 1; next }
  in_case && found_branch && /printf '\''claude-sonnet/ { print "GEN_LEAK" }
  /esac/ && in_case { in_case = 0 }
' "$helper")
if [ -z "$sonnet_in_gen" ]; then
  pass "(10) generator/canonize default branch does NOT pin sonnet"
else
  err "(10) generator/canonize default branch leaks sonnet pinning"
fi

# ------------------------------------------------------------------
echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
