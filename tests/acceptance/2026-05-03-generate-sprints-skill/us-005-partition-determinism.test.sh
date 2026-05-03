#!/usr/bin/env bash
# criterion: AC-005-2
#
# Binding Acceptance Criterion (PRD US-005, ratified 2026-05-03T10:44:11Z):
#   "tests/smoke/partition-determinism.test.sh exits 0 with stdout
#    `PASS: byte-identical across two runs`."
#
# Also satisfies FR-3 of the binding AC.
#
# Sprint-3 anchors:
#   - sprint task s03-t02 acceptance criterion: "bash exits 0 AND prints
#     `PASS: byte-identical across two runs`".
#   - functional acceptance criterion id: partition-deterministic.
#
# Sr Eng's contract: `partition_tasks <plan-yaml-path>` mutates the plan
# in place. Re-running on the same `tasks` array MUST produce a
# byte-identical `sprint_partition` block.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/generate-sprints/partition/large-24-tasks"
PARTITION_HELPER="lib/generate-sprints/partition.sh"

if [[ ! -f "$FIXTURE/plan-input.yaml" ]]; then
  printf 'FAIL: partition fixture missing at %s\n' "$FIXTURE/plan-input.yaml" >&2
  exit 1
fi
if [[ ! -f "$PARTITION_HELPER" ]]; then
  printf 'FAIL: %s missing — Sprint 3 task s03-t02 mandates the partition helper\n' "$PARTITION_HELPER" >&2
  exit 1
fi

WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

run_partition_once() {
  local out_path="$1"
  local label="$2"
  local sandbox="$WORK_TREE/run-$label"
  mkdir -p "$sandbox/.yoke/runtime"
  cp "$REPO_ROOT/$FIXTURE/plan-input.yaml" "$sandbox/.yoke/runtime/.generate-sprints-plan.yaml"

  (
    cd "$sandbox"
    set +e
    bash -c "
      set -e
      source '$REPO_ROOT/lib/generate-sprints/plan-io.sh'
      source '$REPO_ROOT/$PARTITION_HELPER'
      partition_tasks .yoke/runtime/.generate-sprints-plan.yaml
    "
  ) 2>"$sandbox/partition.stderr"
  local rc=$?
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAIL: partition_tasks exited rc=%d during deterministic-run #%s\n' "$rc" "$label" >&2
    sed 's/^/        /' "$sandbox/partition.stderr" >&2 || true
    return 1
  fi

  # Extract just the sprint_partition block for the diff.
  python3 - "$sandbox/.yoke/runtime/.generate-sprints-plan.yaml" > "$out_path" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    plan = yaml.safe_load(f) or {}
sp = plan.get("sprint_partition") or []
sys.stdout.write(yaml.safe_dump({"sprint_partition": sp}, sort_keys=False, default_flow_style=False))
PY
  return 0
}

run_partition_once "$WORK_TREE/run1.yaml" 1 || exit 1
run_partition_once "$WORK_TREE/run2.yaml" 2 || exit 1

if ! diff -q "$WORK_TREE/run1.yaml" "$WORK_TREE/run2.yaml" >/dev/null 2>&1; then
  printf 'FAIL: AC-005-2 violated — sprint_partition differs across two runs\n' >&2
  printf '      diff:\n' >&2
  diff "$WORK_TREE/run1.yaml" "$WORK_TREE/run2.yaml" | sed 's/^/        /' >&2 || true
  exit 1
fi

printf 'PASS: byte-identical across two runs\n'
printf '\n--- Result ---\nPASS: us-005-partition-determinism\n'
exit 0
