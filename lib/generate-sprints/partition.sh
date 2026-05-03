#!/usr/bin/env bash
# partition.sh — deterministic Bash + Python helper that partitions the
# synthesized task list at `.yoke/runtime/.generate-sprints-plan.yaml ::
# tasks` into sprints with explicit delivery objectives and binary DoD
# lists, then writes the resulting partition into the same plan file
# under `:: sprint_partition`.
#
# Stage 4 of the `/yoke:generate-sprints` blueprint (after Stage 3
# Synthesis, before Stage 5 Render). The synthesis stage emits tasks
# with placeholder `task_id` values (`T-1`, `T-2`, ...); this stage
# assigns final `<slug>-s<NN>-t<MM>` ids in walk order and groups them
# into sprints. The stage is intentionally LLM-free — re-running
# against an unchanged `tasks` array MUST produce byte-identical
# `sprint_partition` output (FR-3 of the binding AC, AC-005-2).
#
# Algorithm (deterministic):
#   1. Read `tasks` from the plan.
#   2. Build an undirected graph where two tasks share an edge when
#      they share ≥ 2 entries from their `applies_decisions` lists
#      ("tech-spec-overlap"). Connected components become candidate
#      sprints.
#   3. Cap each component at 8 tasks. When a component exceeds the
#      cap, split into multiple sprints by sorting the component's
#      tasks lexicographically by `acceptance_criterion` and chunking
#      by 8 (the cap).
#   4. Order sprints lexicographically by their first task's
#      placeholder id (`T-<n>`, numeric-sorted) so re-runs converge.
#   5. Within each sprint, order tasks lexicographically by their
#      placeholder id (numeric-sorted) so the walk order is stable.
#   6. Per resulting sprint compute:
#        delivery_objective = "<concat realized US titles>; anchored on
#                              <dominant spec anchor>"
#        dod                = ["<final-task-id>: <acceptance_criterion>",
#                              ...]  (one entry per task)
#   7. Assign final ids `<slug>-s<NN>-t<MM>` in walk order (sprint 1
#      → t01..; sprint 2 → t01..; ...).
#
# I/O contract:
#   - Caller: `partition_tasks <plan-yaml-path>`
#       Reads `<plan-yaml-path>::tasks`, writes `<plan-yaml-path>::
#       sprint_partition` and rewrites every task's `task_id` to its
#       final `<slug>-s<NN>-t<MM>` form. Exits 0 on success; non-zero
#       with `wm:`-prefixed stderr on failure (missing file, empty
#       tasks array, malformed task entry, partition cap violation).
#
# Invariants:
#   - Pure shell + python3. No yq dependency for the in-place write
#     (yq has a non-trivial behavioural difference between v4.x minor
#     versions when handling block-vs-inline sequences inside `-i`
#     mutations; we serialise the new YAML deterministically with
#     PyYAML's `safe_dump` and overwrite the plan file).
#   - Cap enforced at 8 (AC-005-5 upper bound).
#   - Cap floor enforced at 1 (no empty sprints; AC-005-5 lower bound).
#
# Tests: `tests/runtime/partition.test.sh` (happy-path unit, owned by
# Sr Eng); `tests/smoke/partition-determinism.test.sh` and
# `tests/smoke/render-bundle-shape.test.sh` (acceptance, owned by
# Sr QA).

# Idempotent re-source guard.
if [[ -n "${_GENERATE_SPRINTS_PARTITION_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _GENERATE_SPRINTS_PARTITION_LOADED=1

# Internal: emit "wm:"-prefixed stderr and return 1.
_gs_partition_fail() {
    echo "wm: $1" >&2
    return 1
}

# partition_tasks <plan-yaml-path>
#   Mutates <plan-yaml-path> in place: rewrites every task's `task_id`
#   to its final `<slug>-s<NN>-t<MM>` form and populates
#   `sprint_partition` with one entry per produced sprint. The function
#   is deterministic — re-running against an unchanged `tasks` array
#   produces byte-identical output (FR-3 of the binding AC).
partition_tasks() {
    local plan_path="${1:-}"
    if [[ -z "$plan_path" ]]; then
        _gs_partition_fail "partition_tasks requires <plan-yaml-path>"
        return $?
    fi
    if [[ ! -f "$plan_path" ]]; then
        _gs_partition_fail "plan file not found: $plan_path"
        return $?
    fi

    local out
    out="$(python3 - "$plan_path" 2>&1 <<'PY'
import json
import re
import sys

# yq's parser was rejected as the in-place mutation surface (see
# header comment). PyYAML is the deterministic serialiser used here.
try:
    import yaml
except Exception as exc:
    print(f"wm: PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(1)

path = sys.argv[1]

try:
    with open(path, encoding="utf-8") as f:
        plan = yaml.safe_load(f) or {}
except Exception as exc:
    print(f"wm: failed to parse plan YAML at {path}: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(plan, dict):
    print(f"wm: plan file is not a YAML mapping: {path}", file=sys.stderr)
    sys.exit(1)

slug = plan.get("slug", "")
if not isinstance(slug, str) or not slug:
    print("wm: plan missing top-level 'slug' key", file=sys.stderr)
    sys.exit(1)

tasks = plan.get("tasks", [])
if not isinstance(tasks, list) or not tasks:
    print("wm: plan 'tasks' array is empty or missing; run synthesis first",
          file=sys.stderr)
    sys.exit(1)

# Per-cap invariants.
SPRINT_CAP = 8

# --- Validate every task entry -------------------------------------------

placeholder_re = re.compile(r"^T-(\d+)$")
us_re = re.compile(r"^US-[0-9]{3}$")

for idx, task in enumerate(tasks):
    if not isinstance(task, dict):
        print(f"wm: task[{idx}] is not a YAML mapping", file=sys.stderr)
        sys.exit(1)
    tid = task.get("task_id", "")
    if not isinstance(tid, str) or not placeholder_re.match(tid):
        print(
            f"wm: task[{idx}] has invalid placeholder task_id '{tid}' "
            f"(expected 'T-<n>')",
            file=sys.stderr,
        )
        sys.exit(1)
    rus = task.get("realizes_user_stories", [])
    if not isinstance(rus, list) or not rus:
        print(
            f"wm: task '{tid}' missing non-empty realizes_user_stories",
            file=sys.stderr,
        )
        sys.exit(1)
    for us in rus:
        if not isinstance(us, str) or not us_re.match(us):
            print(
                f"wm: task '{tid}' has invalid realizes_user_stories entry "
                f"'{us}' (expected 'US-NNN')",
                file=sys.stderr,
            )
            sys.exit(1)
    deps = task.get("applies_decisions", [])
    if not isinstance(deps, list):
        print(
            f"wm: task '{tid}' applies_decisions must be a list",
            file=sys.stderr,
        )
        sys.exit(1)
    if not isinstance(task.get("instructions", ""), str):
        print(
            f"wm: task '{tid}' instructions must be a string",
            file=sys.stderr,
        )
        sys.exit(1)
    crit = task.get("acceptance_criterion", "")
    if not isinstance(crit, str) or not crit:
        print(
            f"wm: task '{tid}' missing non-empty acceptance_criterion",
            file=sys.stderr,
        )
        sys.exit(1)

# Index tasks by their placeholder numeric suffix so the stable
# ordering across all stages is "ascending T-<n>".
def placeholder_num(t):
    return int(placeholder_re.match(t["task_id"]).group(1))

tasks_sorted = sorted(tasks, key=placeholder_num)

# --- Build the overlap graph ---------------------------------------------
#
# Two tasks share an edge when they share ≥ 2 entries from their
# applies_decisions lists. Connected components become candidate
# sprints. The graph is undirected; edges are computed pairwise on
# the sorted task list.

n = len(tasks_sorted)
parent = list(range(n))

def find(x):
    while parent[x] != x:
        parent[x] = parent[parent[x]]
        x = parent[x]
    return x

def union(a, b):
    ra, rb = find(a), find(b)
    if ra != rb:
        # Always attach the larger-id root to the smaller-id root so
        # the resulting component-id sort is stable across runs.
        if ra < rb:
            parent[rb] = ra
        else:
            parent[ra] = rb

for i in range(n):
    di = set(tasks_sorted[i].get("applies_decisions", []) or [])
    for j in range(i + 1, n):
        dj = set(tasks_sorted[j].get("applies_decisions", []) or [])
        if len(di & dj) >= 2:
            union(i, j)

# Group indices by component root.
groups = {}
for i in range(n):
    r = find(i)
    groups.setdefault(r, []).append(i)

# Convert each group's indices into the actual task dicts. Order
# inside a group is "ascending placeholder T-<n>" (already the order
# of tasks_sorted).
candidate_sprints = []
for root in sorted(groups.keys()):
    indices = sorted(groups[root])
    candidate_sprints.append([tasks_sorted[i] for i in indices])

# --- Cap each candidate at SPRINT_CAP ------------------------------------
#
# When a candidate sprint exceeds 8 tasks, split it into chunks of 8.
# The chunk order follows the candidate's existing in-group order
# (ascending placeholder), which is already deterministic. The spec'd
# fallback "split by acceptance_criterion lexical clustering" reduces
# to "sort by acceptance_criterion then chunk" — but the placeholder
# ordering already encodes the synthesis stage's intended walk order;
# resorting on the criterion text would lose that signal. We honour
# the spec's intent (deterministic split when the cap is exceeded) by
# applying the lexical sort only inside oversized groups, falling back
# to placeholder ordering for ties.

def split_oversize(group):
    if len(group) <= SPRINT_CAP:
        return [group]
    # Re-order by acceptance_criterion, then by placeholder ordinal
    # for ties. This is the documented "lexical clustering" sort.
    keyed = sorted(
        group,
        key=lambda t: (t.get("acceptance_criterion", ""), placeholder_num(t)),
    )
    chunks = []
    for start in range(0, len(keyed), SPRINT_CAP):
        chunks.append(keyed[start:start + SPRINT_CAP])
    return chunks

final_sprints = []
for group in candidate_sprints:
    final_sprints.extend(split_oversize(group))

# Re-order sprints across the partition by their first task's
# placeholder numeric suffix (ascending). The intra-sprint task
# ordering is preserved from the previous step.
final_sprints.sort(key=lambda s: placeholder_num(s[0]))

if not final_sprints:
    print("wm: partition produced zero sprints (defensive guard)",
          file=sys.stderr)
    sys.exit(1)

for s_idx, s in enumerate(final_sprints, start=1):
    if not (1 <= len(s) <= SPRINT_CAP):
        print(
            f"wm: sprint s{s_idx:02d} has {len(s)} tasks (expected 1..{SPRINT_CAP})",
            file=sys.stderr,
        )
        sys.exit(1)

# --- Assign final task ids and build sprint_partition --------------------

# Lookup of placeholder id -> final id, applied at the end so the
# instructions block can carry forward unchanged from synthesis.
final_id_by_placeholder = {}

partition_entries = []

for s_idx, sprint in enumerate(final_sprints, start=1):
    sprint_id = f"{slug}-s{s_idx:02d}"

    # Collect realized user-story titles in first-encounter order across
    # the sprint's tasks. Used for the delivery_objective summary.
    seen_us = []
    for task in sprint:
        for us in task.get("realizes_user_stories", []):
            if us not in seen_us:
                seen_us.append(us)

    # Pick the dominant spec anchor (the one shared by the most tasks
    # in this sprint; ties broken lexicographically). Empty string when
    # no spec anchor is present at all.
    anchor_counts = {}
    for task in sprint:
        for anchor in task.get("applies_decisions", []) or []:
            anchor_counts[anchor] = anchor_counts.get(anchor, 0) + 1
    if anchor_counts:
        # Sort by (-count, anchor) so most-frequent wins; lexical tie-break.
        dominant_anchor = sorted(
            anchor_counts.items(), key=lambda kv: (-kv[1], kv[0])
        )[0][0]
    else:
        dominant_anchor = ""

    # delivery_objective: deterministic concatenation. We use the
    # ascending US ordering for stability — even though "first
    # encounter" in the sprint's task walk is already deterministic,
    # ascending US order is friendlier to humans scanning the bundle.
    sorted_us = sorted(seen_us)
    if dominant_anchor:
        delivery_objective = (
            f"Realize {', '.join(sorted_us)} anchored on '{dominant_anchor}'."
        )
    else:
        delivery_objective = f"Realize {', '.join(sorted_us)}."

    # Assign final task ids and build the per-sprint dod.
    sprint_task_ids = []
    sprint_dod = []
    for t_idx, task in enumerate(sprint, start=1):
        final_id = f"{slug}-s{s_idx:02d}-t{t_idx:02d}"
        final_id_by_placeholder[task["task_id"]] = final_id
        sprint_task_ids.append(final_id)
        sprint_dod.append(f"{final_id}: {task['acceptance_criterion']}")

    partition_entries.append({
        "sprint_id": sprint_id,
        "delivery_objective": delivery_objective,
        "dod": sprint_dod,
        "task_ids": sprint_task_ids,
    })

# Apply the placeholder -> final id rewrite to every task. We mutate
# the original `tasks` list in-place so any extra keys that the
# synthesis stage attached survive untouched.
for task in tasks:
    placeholder = task.get("task_id", "")
    final = final_id_by_placeholder.get(placeholder)
    if not final:
        # Defensive guard: every placeholder MUST have been mapped.
        print(
            f"wm: task '{placeholder}' was not assigned to any sprint",
            file=sys.stderr,
        )
        sys.exit(1)
    task["task_id"] = final

# Re-order tasks to match the partition walk order (sprint 1 t01..tNN,
# sprint 2 t01..tNN, ...). This makes the plan file's `tasks` array
# aligned with the `sprint_partition`'s `task_ids` walk — downstream
# render and diff tooling depend on this ordering.
ordered_tasks = []
final_id_to_task = {t["task_id"]: t for t in tasks}
for entry in partition_entries:
    for tid in entry["task_ids"]:
        ordered_tasks.append(final_id_to_task[tid])

plan["tasks"] = ordered_tasks
plan["sprint_partition"] = partition_entries

# --- Serialise back deterministically ------------------------------------

# Use safe_dump with sort_keys=False to preserve the documented top-
# level key order (slug, generated_at, tasks, sprint_partition). The
# default flow style is block, matching the synthesis-stage emission.
try:
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(
            plan,
            f,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
            width=10_000,  # do not wrap long instruction blocks
        )
except Exception as exc:
    print(f"wm: failed to write partitioned plan: {exc}", file=sys.stderr)
    sys.exit(1)

print(f"wm: partitioned {len(tasks)} task(s) into {len(partition_entries)} sprint(s)",
      file=sys.stderr)
PY
    )"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        if [[ -n "$out" ]]; then
            printf '%s\n' "$out" >&2
        fi
        return 1
    fi
    # Surface the python helper's diagnostic stderr line (it's already
    # written to fd 2 when `out` was captured with the `2>&1` merge);
    # we re-emit any merged content for visibility but suppress the
    # success path stdout (there is none).
    if [[ -n "$out" ]]; then
        printf '%s\n' "$out" >&2
    fi
    return 0
}
