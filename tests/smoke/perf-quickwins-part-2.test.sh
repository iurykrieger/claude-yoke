#!/bin/bash
# tests/smoke/perf-quickwins-part-2.test.sh
#
# Smoke test for Part 2 of the runtime perf-quickwins:
#   (a) agents/generator.md mandates plan-first behavior every cycle
#   (b) agents/generator.md licenses batched coupled criteria with the
#       conservative coupling heuristic
#   (c) templates/progress.md carries the plan: block schema with all
#       required fields
#   (d) tests/fixtures/perf-quickwins-part-2/progress-with-plan.md parses
#       per the schema and exercises the coupling case
#       (coupled_groups[0].criteria has length ≥ 2)
#
# /yoke:implement is a Claude Code skill that spawns subagents at
# runtime, so a pure-bash smoke test cannot drive it end-to-end.
# Instead this test verifies the static surfaces the spec governs:
# persona text in agents/generator.md, schema in templates/progress.md,
# and a fixture progress.md that demonstrates the schema can express
# the coupling case Part 2 enables.
#
# Self-imposed 600s watchdog (per .vibeflow/conventions.md).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- perf-quickwins-part-2 smoke ---"

# 600s watchdog. Redirect stdin/stdout/stderr to /dev/null so the
# subshell does NOT hold the script's stdout open after the trap fires.
( exec </dev/null >/dev/null 2>&1; sleep 600 && kill -TERM $$ 2>/dev/null ) &
watchdog_pid=$!
trap 'pkill -P "$watchdog_pid" 2>/dev/null || true; kill "$watchdog_pid" 2>/dev/null || true' EXIT

# ------------------------------------------------------------------
# (a) Plan-first behavior in agents/generator.md
# ------------------------------------------------------------------
gen="agents/generator.md"
[ -f "$gen" ] || err "missing $gen"

# DoD #1: persona phrases that signal plan-first instinct
for phrase in \
  "Plan before you edit, every cycle" \
  "Read every currently-failing criterion" \
  "Name the change set" \
  "BEFORE applying any edits"; do
  if grep -qF "$phrase" "$gen"; then
    pass "(a) persona mandates: $phrase"
  else
    err "(a) persona missing phrase: $phrase"
  fi
done

# Senior-engineer / planning persona language. Accept either the
# Part-2-only framing ("Senior engineer who plans") or the merged
# framing that integrates main's "Senior Developer (Coding-Agent role)"
# with the plan-first instinct.
if grep -qE "Senior engineer who plans" "$gen" \
   || grep -qE "Senior Developer.*who plans" "$gen"; then
  pass "(a) Persona section sharpened (planner-first framing)"
else
  err "(a) Persona section missing the planner-first framing"
fi

# ------------------------------------------------------------------
# (b) Batched coupled criteria license + conservative coupling heuristic
# ------------------------------------------------------------------

# DoD #2: batching license + heuristic
for phrase in \
  "Batch coupled criteria within a cycle when" \
  "tech-spec-overlap" \
  "sensor-evidence-overlap" \
  "When in doubt, **do not couple**"; do
  if grep -qF "$phrase" "$gen"; then
    pass "(b) batching license / heuristic: $phrase"
  else
    err "(b) batching license missing phrase: $phrase"
  fi
done

# Plural citing field documented
if grep -qF "citing_criteria:" "$gen"; then
  pass "(b) generator.md documents citing_criteria: (plural) for batched cycles"
else
  err "(b) generator.md missing citing_criteria: documentation"
fi

# Generator authority preserved (anti-scope: no canonical-memory writes)
if grep -qF "Never write canonical memory" "$gen"; then
  pass "(b) Generator authority preserved (still no canonical-memory writes)"
else
  err "(b) Generator authority appears altered — 'Never write canonical memory' missing"
fi

# ------------------------------------------------------------------
# (c) templates/progress.md schema
# ------------------------------------------------------------------
tmpl="templates/progress.md"
[ -f "$tmpl" ] || err "missing $tmpl"

# DoD #3: required fields
for field in \
  "plan:" \
  "cycle:" \
  "failing_criteria_read:" \
  "coupled_groups:" \
  "group_id:" \
  "criteria:" \
  "shared_files:" \
  "coupling_signal:" \
  "change_set:" \
  "citing_criteria:"; do
  if grep -qF "$field" "$tmpl"; then
    pass "(c) progress.md schema includes '$field'"
  else
    err "(c) progress.md schema missing '$field'"
  fi
done

# Backward-compat: existing fields preserved
for field in \
  "timestamp:" \
  "next_step:" \
  "files_touched:" \
  "sensor_feedback_consumed:" \
  "contract_consensus_reached:" \
  "citing_criterion:"; do
  if grep -qF "$field" "$tmpl"; then
    pass "(c) backward-compat: '$field' still present"
  else
    err "(c) backward-compat broken — '$field' removed"
  fi
done

# Coupling-signal allowed values documented
for val in tech-spec-overlap sensor-evidence-overlap both; do
  if grep -qF "\`$val\`" "$tmpl"; then
    pass "(c) coupling_signal value '$val' documented"
  else
    err "(c) coupling_signal value '$val' missing from schema notes"
  fi
done

# Single-element coupled_groups is documented as a self-bug
if grep -qE "single-element groups are a self-bug" "$tmpl"; then
  pass "(c) schema rejects single-element coupled_groups (self-bug)"
else
  err "(c) schema does NOT reject single-element coupled_groups"
fi

# ------------------------------------------------------------------
# (d) Fixture parses and exercises the coupling case
# ------------------------------------------------------------------
fix="tests/fixtures/perf-quickwins-part-2/progress-with-plan.md"
[ -f "$fix" ] || err "missing fixture $fix"

# Plan: block present (matches both "- plan:" and "    plan:" YAML shapes)
grep -qE "^[[:space:]]*-?[[:space:]]*plan:" "$fix" \
  && pass "(d) fixture contains plan: block" \
  || err "(d) fixture missing plan: block"

# Each plan: subfield present
for field in \
  "cycle:" \
  "failing_criteria_read:" \
  "coupled_groups:" \
  "change_set:" \
  "shared_files:" \
  "coupling_signal:"; do
  grep -qE "^[[:space:]]+${field}" "$fix" \
    && pass "(d) fixture populates '${field}'" \
    || err "(d) fixture missing '${field}'"
done

# coupled_groups[0].criteria has length ≥ 2 — this is the spec's
# explicit assertion. Parse the criteria array out of the YAML-in-md.
criteria_line=$(awk '
  /^[[:space:]]+coupled_groups:/ { in_cg = 1; next }
  in_cg && /^[[:space:]]+criteria:/ { print; exit }
  in_cg && /^[[:space:]]+- /  { sub_seen = 1 }
  /^[^[:space:]]/ { in_cg = 0 }
' "$fix")
if [ -z "$criteria_line" ]; then
  err "(d) could not locate criteria: line under coupled_groups in fixture"
else
  # Count comma-separated entries inside [ ]
  list=$(echo "$criteria_line" | sed -E 's/.*\[(.*)\].*/\1/')
  count=$(echo "$list" | tr ',' '\n' | grep -c '"')
  if [ "$count" -ge 2 ]; then
    pass "(d) coupled_groups[0].criteria length = $count (≥ 2)"
  else
    err "(d) coupled_groups[0].criteria length = $count (expected ≥ 2)"
  fi
fi

# citing_criteria: (plural) populated when batching
grep -qE "^- citing_criteria:[[:space:]]*\[" "$fix" \
  && pass "(d) fixture uses citing_criteria: (plural) for batched cycle" \
  || err "(d) fixture missing citing_criteria: plural form"

# ------------------------------------------------------------------
# Anti-scope: no Validator-verdict shape change, no Orchestrator change,
# no parallel-spawn change, no upstream-artifact mutation
# ------------------------------------------------------------------
# The "Never modify" bullet wraps across two lines — the first line
# names .yoke/prds/ and .yoke/tech-specs/, the second line names
# .yoke/acceptance-contracts/. Check each path token independently.
if grep -qE "Never modify" "$gen" \
   && grep -qF ".yoke/prds/" "$gen" \
   && grep -qF ".yoke/tech-specs/" "$gen" \
   && grep -qF ".yoke/acceptance-contracts/" "$gen"; then
  pass "(anti) Generator still cannot modify upstream artifacts"
else
  err "(anti) Generator restrictions on upstream artifacts weakened"
fi

# Validator file untouched in this part — ensure DoD #6 (anti-scope) holds
# (we cannot diff files in a smoke test, but we can at least confirm the
# Validator's structured-JSON verdict shape comment block is still there)
if grep -q "Emit structured JSON verdicts" agents/validator.md; then
  pass "(anti) Validator's structured-JSON verdict shape preserved"
else
  err "(anti) Validator's verdict shape appears altered (anti-scope violation)"
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
