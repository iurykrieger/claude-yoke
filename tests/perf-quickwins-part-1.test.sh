#!/bin/bash
# tests/perf-quickwins-part-1.test.sh
#
# Smoke test for Part 1 of the runtime perf-quickwins:
#   (a) hooks/verify-acceptance.sh --criterion <id> filters correctly
#   (b) parallel execution beats serial wall-clock by ≥ 30 %
#   (c) the cycle invokes sensors exactly once (counter-sensor stays at 1
#       across step-2 + post-iteration.sh)
#   (d) MERGE-READY runs the full suite with --concurrency 1 (no scoping)
#
# Self-imposed 600s watchdog (per .vibeflow/conventions.md) runs in a
# background subshell; if the test exceeds the budget it terminates the
# parent and reports.
#
# Baseline numbers (serial vs parallel) are archived to
# .vibeflow/audits/perf-quickwins-baseline.yaml so PRD-level
# instrumentation lands alongside v0.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- perf-quickwins-part-1 smoke ---"

tmpdir="$(mktemp -d)"
# 600s watchdog. Redirect stdin/stdout/stderr to /dev/null so the
# subshell does NOT hold the script's stdout open after the trap fires.
( exec </dev/null >/dev/null 2>&1; sleep 600 && kill -TERM $$ 2>/dev/null ) &
watchdog_pid=$!
# pkill -P kills the inner sleep too; without it sleep is reparented
# and keeps inherited file descriptors alive (blocks pipe consumers).
trap 'pkill -P "$watchdog_pid" 2>/dev/null || true; kill "$watchdog_pid" 2>/dev/null || true; rm -rf "$tmpdir"' EXIT

# ------------------------------------------------------------------
# Fixture: 3 sensors mapped to 2 scenarios + 2 FRs
# ------------------------------------------------------------------
contract="$tmpdir/contract.md"
cat > "$contract" <<'EOF'
# Acceptance Contract — fixture

> Status: ratified

## Use cases (BDD scenarios)

### Scenario 1 — fast path
Given a request
When processed
Then result returned
Fixture: none
Sensors: [linter, type-check]

### Scenario 2 — slow path
Given a request
When delayed
Then result eventually
Fixture: none
Sensors: [unit-test]

## Functional requirements

- [ ] **FR-1** — fast. Sensor: linter.
- [ ] **FR-2** — slow. Sensor: unit-test.

## Sensors

### Computational

- linter: `bash -c "sleep 1; echo lint-ok; exit 0"`
- type-check: `bash -c "sleep 1; echo tc-ok; exit 0"`
- unit-test: `bash -c "sleep 1; echo unit-ok; exit 0"`
EOF

# ------------------------------------------------------------------
# (a) --criterion filters correctly
# ------------------------------------------------------------------
out=$(bash hooks/verify-acceptance.sh "$contract" --criterion "Scenario 1")
if echo "$out" | grep -q 'sensor: "linter"' && echo "$out" | grep -q 'sensor: "type-check"'; then
  pass "(a) --criterion 'Scenario 1' includes linter + type-check"
else
  err "(a) --criterion 'Scenario 1' missing expected sensors:"$'\n'"$out"
fi
if echo "$out" | grep -q 'sensor: "unit-test"'; then
  err "(a) --criterion 'Scenario 1' should NOT include unit-test:"$'\n'"$out"
else
  pass "(a) --criterion 'Scenario 1' excludes unit-test"
fi

out=$(bash hooks/verify-acceptance.sh "$contract" --criterion "FR-1")
if echo "$out" | grep -q 'sensor: "linter"' && ! echo "$out" | grep -q 'sensor: "type-check"' && ! echo "$out" | grep -q 'sensor: "unit-test"'; then
  pass "(a) --criterion 'FR-1' isolates to single sensor (linter)"
else
  err "(a) --criterion 'FR-1' did not isolate to linter:"$'\n'"$out"
fi

# ------------------------------------------------------------------
# (b) parallel beats serial by ≥ 30 % (ratio ≤ 0.7)
# Median over 2 runs per leg to dampen CI noise (Risk R2 mitigation).
# ------------------------------------------------------------------
median_ns() {
  local a=$1 b=$2
  if [ "$a" -le "$b" ]; then echo "$a"; else echo "$b"; fi
}

leg() {
  local conc="$1"
  local start end
  start=$(date +%s%N)
  bash hooks/verify-acceptance.sh "$contract" --concurrency "$conc" >/dev/null
  end=$(date +%s%N)
  echo $((end - start))
}

s1=$(leg 1); s2=$(leg 1)
serial_ns=$(median_ns "$s1" "$s2")
p1=$(leg 4); p2=$(leg 4)
parallel_ns=$(median_ns "$p1" "$p2")

ratio_pct=$((parallel_ns * 100 / serial_ns))
echo "  serial(min)=${serial_ns}ns parallel(min)=${parallel_ns}ns ratio=${ratio_pct}%"
if [ "$ratio_pct" -le 70 ]; then
  pass "(b) parallel ≥ 30 % faster than serial (ratio ${ratio_pct}% ≤ 70%)"
else
  err "(b) parallel NOT ≥ 30 % faster (ratio ${ratio_pct}% > 70%)"
fi

# ------------------------------------------------------------------
# (c) Cycle invokes sensors exactly once.
# Set up a minimal .yoke/ tree, write a fixture contract whose sole
# sensor increments a counter, then drive the SKILL.md flow:
#   step 2: verify-acceptance.sh --criterion FR-X --fragments-dir ... > .pending-snapshot
#   step 4: post-iteration.sh promotes scratch → cycle-1.yaml
# Counter must be 1 (not 2) at the end.
# ------------------------------------------------------------------
yoke_root="$tmpdir/host"
mkdir -p "$yoke_root"
cd "$yoke_root"

mkdir -p .yoke/runtime .yoke/acceptance-contracts
echo "config_version: 1" > .yoke/config.yaml
slug="2026-04-25-counter-fixture"
echo -n "$slug" > .yoke/runtime/.current

counter_file="$tmpdir/exec-counter"
echo 0 > "$counter_file"

cat > ".yoke/acceptance-contracts/${slug}.md" <<EOF
# Acceptance Contract — counter

> Status: ratified

## Use cases (BDD scenarios)

### Scenario 1 — counted
Given a request
When processed
Then count incremented
Fixture: none
Sensors: [counter]

## Functional requirements

- [ ] **FR-1** — counted. Sensor: counter.

## Sensors

### Computational

- counter: \`bash -c 'n=\$(cat $counter_file); echo \$((n+1)) > $counter_file; echo ok'\`
EOF

# Step 2 of SKILL.md (coordinator's single per-cycle execution).
bash "$PLUGIN_ROOT/hooks/verify-acceptance.sh" \
  --criterion "FR-1" \
  --fragments-dir ".yoke/runtime/.pending-fragments" \
  > ".yoke/runtime/.pending-snapshot.yaml"

mid_count=$(cat "$counter_file")
[ "$mid_count" = "1" ] \
  && pass "(c) verify-acceptance.sh ran the counter sensor exactly once (count=$mid_count after step 2)" \
  || err "(c) counter expected 1 after step 2, got $mid_count"

# Step 4: post-iteration.sh — must promote scratch, not re-run.
bash "$PLUGIN_ROOT/hooks/post-iteration.sh" >/dev/null

post_count=$(cat "$counter_file")
[ "$post_count" = "1" ] \
  && pass "(c) post-iteration.sh promoted scratch without re-running sensors (count=$post_count)" \
  || err "(c) post-iteration.sh re-ran sensors — counter went $mid_count → $post_count (expected 1)"

# Snapshot landed at the cycle-1 location.
[ -f ".yoke/runtime/.snapshots/cycle-1.yaml" ] \
  && pass "(c) snapshot promoted to cycle-1.yaml" \
  || err "(c) cycle-1.yaml missing"
[ -d ".yoke/runtime/.snapshots/cycle-1.fragments" ] \
  && pass "(c) fragments promoted to cycle-1.fragments/" \
  || err "(c) cycle-1.fragments/ missing"
[ ! -f ".yoke/runtime/.pending-snapshot.yaml" ] \
  && pass "(c) scratch .pending-snapshot.yaml removed after promotion" \
  || err "(c) scratch .pending-snapshot.yaml not removed"

cd "$PLUGIN_ROOT"

# ------------------------------------------------------------------
# (d) MERGE-READY runs the full suite (no --criterion, --concurrency 1).
# Verify that the unscoped run includes all 3 sensors and is serial.
# ------------------------------------------------------------------
out=$(bash hooks/verify-acceptance.sh "$contract" --concurrency 1)
for s in linter type-check unit-test; do
  if echo "$out" | grep -q "sensor: \"$s\""; then
    pass "(d) full-suite serial run includes $s"
  else
    err "(d) full-suite serial run missing $s:"$'\n'"$out"
  fi
done

# ------------------------------------------------------------------
# Sensor-output contract preserved (DoD #6 craftsmanship slice).
# ------------------------------------------------------------------
for field in sensor command status exit_code output_excerpt reason; do
  # The first field of each entry is prefixed with "- "; subsequent fields
  # are indented. Match either shape.
  if echo "$out" | grep -qE "^[[:space:]]+(-[[:space:]]+)?${field}:"; then
    pass "(craft) structured output retains '$field' field"
  else
    err "(craft) structured output missing '$field' field"
  fi
done

# ------------------------------------------------------------------
# Baseline numbers archived (PRD instrumentation obligation).
# ------------------------------------------------------------------
audit_dir=".yoke/runtime/audits"
mkdir -p "$audit_dir"
cat > "$audit_dir/perf-quickwins-baseline.yaml" <<EOF
baseline:
  serial_ns: ${serial_ns}
  parallel_ns: ${parallel_ns}
  ratio_pct: ${ratio_pct}
  target_ratio_pct: 70
  fixture_sensors: 3
  fixture_per_sensor_sleep_s: 1
  measured_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  recorded_by: tests/perf-quickwins-part-1.test.sh
EOF
[ -s "$audit_dir/perf-quickwins-baseline.yaml" ] \
  && pass "(audit) baseline archived to $audit_dir/perf-quickwins-baseline.yaml" \
  || err "(audit) baseline file empty or missing"

# ------------------------------------------------------------------
echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
