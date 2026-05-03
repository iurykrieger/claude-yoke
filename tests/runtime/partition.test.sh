#!/usr/bin/env bash
# shellcheck shell=bash
#
# partition.test.sh — Sprint 03 / Task t02 happy-path unit test
# (US-005 partition determinism + cap enforcement, AC-005-2 + AC-005-5).
#
# Asserts that `lib/generate-sprints/partition.sh::partition_tasks`:
#   1. Produces deterministic, byte-identical output across two runs
#      against the same task-list fixture.
#   2. Enforces the [1, 8] per-sprint task-count cap.
#   3. Groups tasks sharing ≥ 2 spec anchors into the same sprint.
#   4. Assigns final task ids `<slug>-s<NN>-t<MM>` in walk order.
#   5. Populates `sprint_partition` with `sprint_id`, `delivery_objective`,
#      `dod`, and `task_ids` keys per partition entry.
#
# This test fixtures a synthetic 4-task plan inline (no on-disk fixture
# directory) so the test is self-contained and re-runnable.
#
# Test contract:
#   - exit 0 with `PASS:` lines on success.
#   - exit non-zero with `wm: partition violation:`-prefixed stderr
#     naming the failed assertion otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: partition violation: %s\n' "$1" >&2
  exit 1
}

# Watchdog (per testing conventions).
( sleep 600 && kill -TERM $$ ) &
WATCHDOG_PID=$!
trap 'kill -TERM "$WATCHDOG_PID" 2>/dev/null || true' EXIT

# Isolated tmp dir.
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"; kill -TERM "$WATCHDOG_PID" 2>/dev/null || true' EXIT

cd "$TMP_ROOT"

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/plan-io.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/partition.sh"

SLUG="2026-01-01-foo"

# --- Bootstrap a synthetic plan with 4 tasks --------------------------------
#
# Two pairs of tasks share ≥ 2 spec anchors:
#   T-1, T-2 share ["A", "B"]    -> sprint 1
#   T-3, T-4 share ["C", "D"]    -> sprint 2
# Expected partition: 2 sprints with 2 tasks each.

init_plan_file "$SLUG" \
  || violation "init_plan_file failed"

PLAN_PATH="${TMP_ROOT}/.yoke/runtime/.generate-sprints-plan.yaml"

python3 - "$PLAN_PATH" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    plan = yaml.safe_load(f)

plan["tasks"] = [
    {
        "task_id": "T-1",
        "realizes_user_stories": ["US-001"],
        "applies_decisions": ["A", "B", "shared"],
        "instructions": "Do thing one.",
        "sensors": ["lint"],
        "acceptance_criterion": "Thing one ships.",
    },
    {
        "task_id": "T-2",
        "realizes_user_stories": ["US-002"],
        "applies_decisions": ["A", "B"],
        "instructions": "Do thing two.",
        "sensors": ["tests-smoke"],
        "acceptance_criterion": "Thing two ships.",
    },
    {
        "task_id": "T-3",
        "realizes_user_stories": ["US-003"],
        "applies_decisions": ["C", "D"],
        "instructions": "Do thing three.",
        "sensors": ["build"],
        "acceptance_criterion": "Thing three ships.",
    },
    {
        "task_id": "T-4",
        "realizes_user_stories": ["US-004", "US-001"],
        "applies_decisions": ["C", "D"],
        "instructions": "Do thing four.",
        "sensors": ["build", "lint"],
        "acceptance_criterion": "Thing four ships.",
    },
]
with open(path, "w") as f:
    yaml.safe_dump(plan, f, default_flow_style=False, sort_keys=False)
PY

# --- Run partition once -----------------------------------------------------

partition_tasks "$PLAN_PATH" \
  || violation "partition_tasks failed on happy-path plan"

# Snapshot the post-partition file for the determinism check.
RUN1_SNAPSHOT="${TMP_ROOT}/run1.yaml"
cp "$PLAN_PATH" "$RUN1_SNAPSHOT"

# --- Assert partition shape --------------------------------------------------

PARTITION_LEN="$(yq -r '.sprint_partition | length' "$PLAN_PATH")"
[[ "$PARTITION_LEN" == "2" ]] \
  || violation "expected 2 sprints, got $PARTITION_LEN"

S1_COUNT="$(yq -r '.sprint_partition[0].task_ids | length' "$PLAN_PATH")"
S2_COUNT="$(yq -r '.sprint_partition[1].task_ids | length' "$PLAN_PATH")"
[[ "$S1_COUNT" == "2" ]] || violation "sprint 1 expected 2 tasks, got $S1_COUNT"
[[ "$S2_COUNT" == "2" ]] || violation "sprint 2 expected 2 tasks, got $S2_COUNT"

S1_ID="$(yq -r '.sprint_partition[0].sprint_id' "$PLAN_PATH")"
S2_ID="$(yq -r '.sprint_partition[1].sprint_id' "$PLAN_PATH")"
[[ "$S1_ID" == "${SLUG}-s01" ]] || violation "sprint 1 id mismatch: $S1_ID"
[[ "$S2_ID" == "${SLUG}-s02" ]] || violation "sprint 2 id mismatch: $S2_ID"

# Final task ids must follow `<slug>-s<NN>-t<MM>`.
T1_ID="$(yq -r '.sprint_partition[0].task_ids[0]' "$PLAN_PATH")"
T2_ID="$(yq -r '.sprint_partition[0].task_ids[1]' "$PLAN_PATH")"
T3_ID="$(yq -r '.sprint_partition[1].task_ids[0]' "$PLAN_PATH")"
T4_ID="$(yq -r '.sprint_partition[1].task_ids[1]' "$PLAN_PATH")"

[[ "$T1_ID" == "${SLUG}-s01-t01" ]] || violation "task[1] id mismatch: $T1_ID"
[[ "$T2_ID" == "${SLUG}-s01-t02" ]] || violation "task[2] id mismatch: $T2_ID"
[[ "$T3_ID" == "${SLUG}-s02-t01" ]] || violation "task[3] id mismatch: $T3_ID"
[[ "$T4_ID" == "${SLUG}-s02-t02" ]] || violation "task[4] id mismatch: $T4_ID"

# Tasks array's task_ids must match the partition walk order.
PLAN_TASK_IDS="$(yq -r '.tasks[].task_id' "$PLAN_PATH" | tr '\n' ',' | sed 's/,$//')"
EXPECTED_IDS="${SLUG}-s01-t01,${SLUG}-s01-t02,${SLUG}-s02-t01,${SLUG}-s02-t02"
[[ "$PLAN_TASK_IDS" == "$EXPECTED_IDS" ]] \
  || violation "tasks walk order mismatch: $PLAN_TASK_IDS"

# Per-sprint dod field shape: one entry per task.
S1_DOD_LEN="$(yq -r '.sprint_partition[0].dod | length' "$PLAN_PATH")"
[[ "$S1_DOD_LEN" == "2" ]] \
  || violation "sprint 1 dod length expected 2, got $S1_DOD_LEN"

# delivery_objective is a non-empty string.
S1_DELIV="$(yq -r '.sprint_partition[0].delivery_objective' "$PLAN_PATH")"
[[ -n "$S1_DELIV" && "$S1_DELIV" != "null" ]] \
  || violation "sprint 1 delivery_objective empty/null"

printf 'PASS: partition shape correct (2 sprints, 2 tasks each, final ids assigned)\n'

# --- Determinism: re-init the plan with the same tasks, run again -----------

# init re-writes the plan with empty arrays + a fresh generated_at.
init_plan_file "$SLUG" >/dev/null
python3 - "$PLAN_PATH" "$RUN1_SNAPSHOT" <<'PY'
import sys, yaml
fresh_path, snapshot_path = sys.argv[1:3]
with open(snapshot_path) as f:
    snapshot = yaml.safe_load(f)
with open(fresh_path) as f:
    plan = yaml.safe_load(f)
# Restore the *placeholder* task ids (T-N) so the second partition run
# sees identical input.
restored = []
for entry in snapshot["sprint_partition"]:
    for tid in entry["task_ids"]:
        # find the task in snapshot by final id, copy with placeholder id.
        for t in snapshot["tasks"]:
            if t["task_id"] == tid:
                clone = dict(t)
                # extract the original ordinal from snapshot ordering.
                clone["task_id"] = f"T-{len(restored) + 1}"
                restored.append(clone)
                break
plan["tasks"] = restored
plan["sprint_partition"] = []
with open(fresh_path, "w") as f:
    yaml.safe_dump(plan, f, default_flow_style=False, sort_keys=False)
PY

partition_tasks "$PLAN_PATH" \
  || violation "partition_tasks failed on second run"

# Compare sprint_partition + final task ids byte-by-byte across runs.
DIFF1="$(yq -r '.sprint_partition' "$RUN1_SNAPSHOT")"
DIFF2="$(yq -r '.sprint_partition' "$PLAN_PATH")"
[[ "$DIFF1" == "$DIFF2" ]] \
  || violation "sprint_partition diverged across two partition runs"

printf 'PASS: byte-identical across two runs\n'

# --- Cap enforcement: 9-task plan must split -------------------------------

init_plan_file "$SLUG" >/dev/null
python3 - "$PLAN_PATH" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    plan = yaml.safe_load(f)
# 9 tasks all sharing the same 2-anchor pair -> single component, must be split.
plan["tasks"] = [
    {
        "task_id": f"T-{i + 1}",
        "realizes_user_stories": [f"US-{i + 1:03d}"],
        "applies_decisions": ["X", "Y"],
        "instructions": f"Task {i + 1}.",
        "sensors": [],
        "acceptance_criterion": f"AC for task {i + 1}.",
    }
    for i in range(9)
]
with open(path, "w") as f:
    yaml.safe_dump(plan, f, default_flow_style=False, sort_keys=False)
PY

partition_tasks "$PLAN_PATH" \
  || violation "partition_tasks failed on 9-task cap-split fixture"

CAP_PARTITION_LEN="$(yq -r '.sprint_partition | length' "$PLAN_PATH")"
[[ "$CAP_PARTITION_LEN" == "2" ]] \
  || violation "9-task fixture expected 2 sprints (split), got $CAP_PARTITION_LEN"

CAP_S1_LEN="$(yq -r '.sprint_partition[0].task_ids | length' "$PLAN_PATH")"
CAP_S2_LEN="$(yq -r '.sprint_partition[1].task_ids | length' "$PLAN_PATH")"
[[ "$CAP_S1_LEN" -le 8 && "$CAP_S2_LEN" -le 8 ]] \
  || violation "cap exceeded: s1=$CAP_S1_LEN s2=$CAP_S2_LEN"
[[ "$CAP_S1_LEN" -ge 1 && "$CAP_S2_LEN" -ge 1 ]] \
  || violation "empty sprint emitted: s1=$CAP_S1_LEN s2=$CAP_S2_LEN"

printf 'PASS: cap enforced (9 tasks split into 2 sprints, both within [1,8])\n'

exit 0
