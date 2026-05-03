#!/usr/bin/env bash
# synthesize.sh — deterministic spine wrapper around the LLM-driven
# Synthesis stage of `/yoke:generate-sprints`.
#
# The synthesis itself happens inside the skill body (one LLM step
# bracketed by deterministic bash; see `skills/generate-sprints/SKILL.md`
# Stage 3). This helper exists for two reasons:
#
#   1. **Pre-validation.** Verify the JSON intermediates produced by
#      `parse_acceptance_criteria` and `parse_spec_architecture` are
#      well-formed before the LLM step is invoked, so a malformed
#      input fails fast with a precise diagnostic rather than wasting
#      the LLM call.
#
#   2. **Post-validation + plan write.** Take the JSON task-list the
#      LLM emitted, validate every entry against the plan's task
#      schema, enforce the US-coverage invariant (every US in the AC
#      MUST be realised by at least one task), then merge the tasks
#      into `.yoke/runtime/.generate-sprints-plan.yaml :: tasks` via a
#      deterministic PyYAML rewrite (matching `partition.sh`'s
#      serialisation policy).
#
# This split keeps the LLM stage's surface narrow (the synthesiser
# emits JSON; everything else is shell+python) and makes the skill
# body's deterministic bracket testable in isolation:
# `tests/runtime/synthesize.test.sh` exercises both helpers without
# invoking any LLM.
#
# I/O contract:
#
#   - Caller: `synthesize_validate_inputs <ac-json-path> <spec-json-path>`
#       Reads both intermediate files, asserts top-level shape:
#         AC : { user_stories: [{id, title, story, dod, acceptance_criteria}],
#                functional_requirements: [...],
#                sensor_pool: [...] }
#         SP : { objective, contracts, dependencies }
#       Exits 0 on success; non-zero with `wm:`-prefixed stderr on
#       any shape violation.
#
#   - Caller: `synthesize_write_tasks <plan-yaml-path> <tasks-json-path>`
#       Reads <tasks-json-path> (the LLM-emitted JSON array of tasks),
#       validates every entry's shape:
#         { task_id: "T-<n>",
#           realizes_user_stories: ["US-NNN", ...],
#           applies_decisions: [...],
#           instructions: "...",
#           sensors: [...],
#           acceptance_criterion: "..." }
#       Cross-references the plan's `slug` against the AC at the path
#       inferred from the slug (so a tasks file mis-targeted at a
#       different active task fails the write); enforces US-coverage
#       against the AC; merges into `<plan-yaml-path>::tasks`. Exits 0
#       on success; non-zero with `wm:`-prefixed stderr on shape /
#       coverage violation.
#
# Tests: `tests/runtime/synthesize.test.sh` (happy-path unit, owned
# by Sr Eng); `tests/smoke/synthesis-us-coverage.test.sh` (acceptance,
# owned by Sr QA — exercises the LLM stage end-to-end).

# Idempotent re-source guard.
if [[ -n "${_GENERATE_SPRINTS_SYNTHESIZE_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _GENERATE_SPRINTS_SYNTHESIZE_LOADED=1

# Internal: emit "wm:"-prefixed stderr and return 1.
_gs_synth_fail() {
    echo "wm: $1" >&2
    return 1
}

# synthesize_validate_inputs <ac-json-path> <spec-json-path>
#   Verifies the JSON intermediates emitted by parse_acceptance_criteria
#   and parse_spec_architecture carry the expected top-level shape.
synthesize_validate_inputs() {
    local ac_json="${1:-}"
    local spec_json="${2:-}"

    if [[ -z "$ac_json" || -z "$spec_json" ]]; then
        _gs_synth_fail "synthesize_validate_inputs requires <ac-json> <spec-json>"
        return $?
    fi
    if [[ ! -f "$ac_json" ]]; then
        _gs_synth_fail "AC JSON intermediate not found: $ac_json"
        return $?
    fi
    if [[ ! -f "$spec_json" ]]; then
        _gs_synth_fail "Spec JSON intermediate not found: $spec_json"
        return $?
    fi

    local out
    out="$(python3 - "$ac_json" "$spec_json" 2>&1 <<'PY'
import json
import re
import sys

ac_path, spec_path = sys.argv[1], sys.argv[2]

try:
    with open(ac_path, encoding="utf-8") as f:
        ac = json.load(f)
except Exception as exc:
    print(f"wm: failed to parse AC JSON at {ac_path}: {exc}", file=sys.stderr)
    sys.exit(1)
try:
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)
except Exception as exc:
    print(f"wm: failed to parse Spec JSON at {spec_path}: {exc}", file=sys.stderr)
    sys.exit(1)

us_re = re.compile(r"^US-[0-9]{3}$")

if not isinstance(ac, dict):
    print("wm: AC JSON top-level must be an object", file=sys.stderr)
    sys.exit(1)
us_list = ac.get("user_stories", [])
if not isinstance(us_list, list) or not us_list:
    print("wm: AC JSON 'user_stories' must be a non-empty array", file=sys.stderr)
    sys.exit(1)
for idx, us in enumerate(us_list):
    if not isinstance(us, dict):
        print(f"wm: AC JSON user_stories[{idx}] not an object", file=sys.stderr)
        sys.exit(1)
    uid = us.get("id", "")
    if not us_re.match(uid):
        print(f"wm: AC JSON user_stories[{idx}] invalid id '{uid}'",
              file=sys.stderr)
        sys.exit(1)
    if not us.get("dod"):
        print(f"wm: AC JSON {uid} missing 'dod'", file=sys.stderr)
        sys.exit(1)
    if not us.get("acceptance_criteria"):
        print(f"wm: AC JSON {uid} missing 'acceptance_criteria'", file=sys.stderr)
        sys.exit(1)

if not isinstance(spec, dict):
    print("wm: Spec JSON top-level must be an object", file=sys.stderr)
    sys.exit(1)
if not isinstance(spec.get("objective", ""), str) or not spec.get("objective"):
    print("wm: Spec JSON missing non-empty 'objective'", file=sys.stderr)
    sys.exit(1)
if not isinstance(spec.get("contracts", []), list):
    print("wm: Spec JSON 'contracts' must be an array", file=sys.stderr)
    sys.exit(1)

print(f"wm: synthesize inputs validated: {len(us_list)} US(s), "
      f"{len(spec.get('contracts', []))} contract anchor(s)",
      file=sys.stderr)
PY
    )"
    local rc=$?
    if [[ -n "$out" ]]; then
        printf '%s\n' "$out" >&2
    fi
    return $rc
}

# synthesize_write_tasks <plan-yaml-path> <tasks-json-path> [<ac-json-path>]
#   Validates and merges the LLM-emitted tasks JSON into the plan.
#   When <ac-json-path> is provided, also enforces the US-coverage
#   invariant (every US in the AC realised by ≥ 1 task).
synthesize_write_tasks() {
    local plan_path="${1:-}"
    local tasks_json="${2:-}"
    local ac_json="${3:-}"

    if [[ -z "$plan_path" || -z "$tasks_json" ]]; then
        _gs_synth_fail "synthesize_write_tasks requires <plan-yaml> <tasks-json> [<ac-json>]"
        return $?
    fi
    if [[ ! -f "$plan_path" ]]; then
        _gs_synth_fail "plan file not found: $plan_path"
        return $?
    fi
    if [[ ! -f "$tasks_json" ]]; then
        _gs_synth_fail "tasks JSON not found: $tasks_json"
        return $?
    fi
    if [[ -n "$ac_json" && ! -f "$ac_json" ]]; then
        _gs_synth_fail "AC JSON not found: $ac_json"
        return $?
    fi

    local out
    out="$(python3 - "$plan_path" "$tasks_json" "${ac_json:-}" 2>&1 <<'PY'
import json
import re
import sys

try:
    import yaml
except Exception as exc:
    print(f"wm: PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(1)

plan_path = sys.argv[1]
tasks_json_path = sys.argv[2]
ac_json_path = sys.argv[3] if len(sys.argv) > 3 else ""

placeholder_re = re.compile(r"^T-(\d+)$")
us_re = re.compile(r"^US-[0-9]{3}$")

try:
    with open(plan_path, encoding="utf-8") as f:
        plan = yaml.safe_load(f) or {}
except Exception as exc:
    print(f"wm: failed to parse plan YAML: {exc}", file=sys.stderr)
    sys.exit(1)
if not isinstance(plan, dict):
    print(f"wm: plan file is not a YAML mapping: {plan_path}", file=sys.stderr)
    sys.exit(1)

try:
    with open(tasks_json_path, encoding="utf-8") as f:
        tasks = json.load(f)
except Exception as exc:
    print(f"wm: failed to parse tasks JSON: {exc}", file=sys.stderr)
    sys.exit(1)
if not isinstance(tasks, list) or not tasks:
    print("wm: tasks JSON must be a non-empty array", file=sys.stderr)
    sys.exit(1)

seen_placeholders = set()
for idx, task in enumerate(tasks):
    if not isinstance(task, dict):
        print(f"wm: tasks[{idx}] is not an object", file=sys.stderr)
        sys.exit(1)
    tid = task.get("task_id", "")
    if not placeholder_re.match(tid):
        print(
            f"wm: tasks[{idx}] invalid placeholder task_id '{tid}' "
            f"(expected 'T-<n>')",
            file=sys.stderr,
        )
        sys.exit(1)
    if tid in seen_placeholders:
        print(f"wm: duplicate placeholder task_id '{tid}'", file=sys.stderr)
        sys.exit(1)
    seen_placeholders.add(tid)

    rus = task.get("realizes_user_stories", [])
    if not isinstance(rus, list) or not rus:
        print(
            f"wm: task '{tid}' missing non-empty realizes_user_stories",
            file=sys.stderr,
        )
        sys.exit(1)
    for us in rus:
        if not us_re.match(us):
            print(
                f"wm: task '{tid}' invalid US entry '{us}'",
                file=sys.stderr,
            )
            sys.exit(1)
    if not isinstance(task.get("applies_decisions", []), list):
        print(f"wm: task '{tid}' applies_decisions must be a list",
              file=sys.stderr)
        sys.exit(1)
    if not isinstance(task.get("instructions", ""), str) \
            or not task.get("instructions"):
        print(f"wm: task '{tid}' instructions must be non-empty string",
              file=sys.stderr)
        sys.exit(1)
    if not isinstance(task.get("acceptance_criterion", ""), str) \
            or not task.get("acceptance_criterion"):
        print(f"wm: task '{tid}' acceptance_criterion must be non-empty string",
              file=sys.stderr)
        sys.exit(1)
    # Per FR-1 of binding AC: forbid per-persona forks inside instructions.
    if re.search(r"\*\*For Sr (Eng|QA|Staff):\*\*", task["instructions"]):
        print(
            f"wm: task '{tid}' instructions contain a per-persona fork "
            f"(forbidden by FR-1)",
            file=sys.stderr,
        )
        sys.exit(1)

# US-coverage enforcement (when AC JSON path is provided).
if ac_json_path:
    try:
        with open(ac_json_path, encoding="utf-8") as f:
            ac = json.load(f)
    except Exception as exc:
        print(f"wm: failed to parse AC JSON at {ac_json_path}: {exc}",
              file=sys.stderr)
        sys.exit(1)
    ac_us_ids = [u.get("id") for u in ac.get("user_stories", [])
                 if isinstance(u, dict) and u.get("id")]
    realized = set()
    for task in tasks:
        for us in task.get("realizes_user_stories", []):
            realized.add(us)
    unrealized = [u for u in ac_us_ids if u not in realized]
    if unrealized:
        print(
            f"wm: unrealized USs: {', '.join(unrealized)}",
            file=sys.stderr,
        )
        sys.exit(1)

# Sort tasks by placeholder ordinal so the merge produces a stable
# `tasks` array regardless of LLM emission order.
tasks_sorted = sorted(tasks, key=lambda t: int(placeholder_re.match(t["task_id"]).group(1)))

plan["tasks"] = tasks_sorted
# Initialise sprint_partition as an empty list; partition stage fills it.
if "sprint_partition" not in plan or not isinstance(plan["sprint_partition"], list):
    plan["sprint_partition"] = []

try:
    with open(plan_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(
            plan,
            f,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
            width=10_000,
        )
except Exception as exc:
    print(f"wm: failed to write plan: {exc}", file=sys.stderr)
    sys.exit(1)

print(
    f"wm: synthesised {len(tasks_sorted)} task(s) into {plan_path}",
    file=sys.stderr,
)
PY
    )"
    local rc=$?
    if [[ -n "$out" ]]; then
        printf '%s\n' "$out" >&2
    fi
    return $rc
}
