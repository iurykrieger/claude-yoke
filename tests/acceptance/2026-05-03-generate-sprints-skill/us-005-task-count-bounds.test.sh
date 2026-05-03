#!/usr/bin/env bash
# criterion: AC-005-5
#
# Binding Acceptance Criterion (PRD US-005, ratified 2026-05-03T10:44:11Z):
#   "No produced sprint contains more than 8 `### Task <ID>` anchors and
#    no produced sprint contains fewer than 1."
#
# Sprint-3 anchors:
#   - sprint task s03-t02 technical implementation: "Cap sprint size at 8
#     tasks" + "no empty sprints".
#   - functional acceptance criterion id: partition-cap-eight-tasks.
#
# Then-clause (binding):
#   GIVEN the partition stage runs against any plan
#   THEN every sprint_partition entry's task count MUST sit within [1, 8].
#   Verified against:
#     (a) tests/fixtures/generate-sprints/partition/small/ (5 tasks → 1 sprint);
#     (b) tests/fixtures/generate-sprints/partition/large-24-tasks/
#         (24 tasks → ≥ 3 sprints, each ≤ 8).

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PARTITION_HELPER="lib/generate-sprints/partition.sh"
if [[ ! -f "$PARTITION_HELPER" ]]; then
  printf 'FAIL: %s missing — Sprint 3 task s03-t02 mandates the partition helper\n' "$PARTITION_HELPER" >&2
  exit 1
fi

WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

run_one() {
  local fixture_dir="$1"
  local label="$2"
  local plan_input="$REPO_ROOT/$fixture_dir/plan-input.yaml"
  local expected_count_file="$REPO_ROOT/$fixture_dir/expected-sprint-count"
  local sandbox="$WORK_TREE/$label"
  mkdir -p "$sandbox/.yoke/runtime"
  cp "$plan_input" "$sandbox/.yoke/runtime/.generate-sprints-plan.yaml"

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
    printf 'FAIL: partition_tasks exited rc=%d on fixture %s\n' "$rc" "$label" >&2
    sed 's/^/        /' "$sandbox/partition.stderr" >&2 || true
    return 1
  fi

  local plan_target="$sandbox/.yoke/runtime/.generate-sprints-plan.yaml"

  # Use PyYAML for stable counts.
  local n_sprints
  n_sprints="$(python3 - "$plan_target" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    plan = yaml.safe_load(f) or {}
sp = plan.get("sprint_partition") or []
print(len(sp))
PY
  )"

  if [[ "$n_sprints" -eq 0 ]]; then
    printf 'FAIL: fixture %s — partition produced zero sprints\n' "$label" >&2
    return 1
  fi

  local expected
  expected="$(cat "$expected_count_file" 2>/dev/null | tr -d '[:space:]' || echo '?')"
  if [[ "$expected" != "?" ]]; then
    if [[ "$label" == "large-24-tasks" ]]; then
      if [[ "$n_sprints" -lt "$expected" ]]; then
        printf 'FAIL: fixture %s — produced %d sprints; expected ≥ %s\n' \
          "$label" "$n_sprints" "$expected" >&2
        return 1
      fi
    else
      if [[ "$expected" != "$n_sprints" ]]; then
        printf 'FAIL: fixture %s — produced %d sprints; expected %s exactly\n' \
          "$label" "$n_sprints" "$expected" >&2
        return 1
      fi
    fi
  fi

  # Iterate sprint partitions and assert task count bounds.
  python3 - "$plan_target" "$label" <<'PY' || return 1
import sys, yaml
plan_path, label = sys.argv[1], sys.argv[2]
with open(plan_path) as f:
    plan = yaml.safe_load(f) or {}
sp = plan.get("sprint_partition") or []
fail = False
for i, entry in enumerate(sp):
    tids = entry.get("task_ids") or []
    n = len(tids)
    if n < 1:
        print(f"FAIL: fixture {label} — sprint #{i+1} has {n} tasks (< 1; empty sprint)", file=sys.stderr)
        fail = True
    elif n > 8:
        print(f"FAIL: fixture {label} — sprint #{i+1} has {n} tasks (> 8; cap violated)", file=sys.stderr)
        fail = True
    else:
        print(f"PASS: fixture {label} sprint #{i+1} has {n} tasks (in [1, 8])")
print(f"PASS: fixture {label} produced {len(sp)} sprints, all within [1, 8] cap")
sys.exit(1 if fail else 0)
PY
  return 0
}

run_one "tests/fixtures/generate-sprints/partition/small" "small" || exit 1
run_one "tests/fixtures/generate-sprints/partition/large-24-tasks" "large-24-tasks" || exit 1

printf '\n--- Result ---\nPASS: us-005-task-count-bounds\n'
exit 0
