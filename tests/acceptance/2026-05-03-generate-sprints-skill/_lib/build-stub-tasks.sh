#!/usr/bin/env bash
# tests/acceptance/2026-05-03-generate-sprints-skill/_lib/build-stub-tasks.sh
#
# QA test infrastructure: deterministic stub for the LLM-driven synthesis
# step. The real synthesis stage is an LLM call inside the skill body
# (per `skills/generate-sprints/SKILL.md` Stage 3). For acceptance tests
# that exercise the deterministic spine *around* the LLM (validators,
# partition, render, Trigger 2.5), we substitute the LLM's output with
# a deterministic transformation of the AC fixture: one task per US,
# placeholder `T-<n>` ids, valid shape, no per-persona forks.
#
# This is QA test infrastructure — it has no production callsite. It
# lives under Sr QA's `tests/acceptance/<contract-slug>/_lib/` lane
# per the council role contract (`agents/sr-qa.md` :: Allowed tools).
#
# Contract:
#   build_stub_tasks_json <ac-json-path> [--missing-us US-NNN[,US-MMM]]
#       Emits on stdout a JSON array shaped per the binding contract:
#         [
#           {
#             "task_id": "T-1",
#             "realizes_user_stories": ["US-001"],
#             "applies_decisions": ["spec.md#main"],
#             "instructions": "Realize US-001.",
#             "sensors": ["tests-smoke"],
#             "acceptance_criterion": "tests/smoke/us-001.test.sh exits 0"
#           },
#           ...
#         ]
#       When --missing-us is provided, the listed US ids are deliberately
#       omitted from any task's realizes_user_stories array (uncovered-US
#       branch; exercises the AC-004-2 abort path).

# NOTE: deliberately does NOT enable `set -euo pipefail` at file scope.
# When sourced into a bash -c subshell that calls
# `synthesize_write_tasks`, leaking `set -e` causes the parent shell to
# exit at the first non-zero command substitution INSIDE
# `synthesize_write_tasks` (the captured python3 stderr) — silently
# swallowing the diagnostic before the helper re-emits it. The helper
# itself uses explicit `return` codes for error paths, so set -e is
# unnecessary.

build_stub_tasks_json() {
  local ac_json="${1:-}"
  local missing="${2:-}"

  if [[ -z "$ac_json" || ! -f "$ac_json" ]]; then
    echo "wm: build_stub_tasks_json requires a readable <ac-json>" >&2
    return 1
  fi

  python3 -u - "$ac_json" "$missing" <<'PY'
import json
import sys

ac_path = sys.argv[1]
missing_arg = sys.argv[2] if len(sys.argv) > 2 else ""

# Parse "--missing-us=US-003" or "--missing-us US-003,US-004"
omit = set()
if missing_arg:
    cleaned = missing_arg.replace("--missing-us=", "").replace("--missing-us ", "")
    for token in cleaned.split(","):
        t = token.strip()
        if t:
            omit.add(t)

with open(ac_path, encoding="utf-8") as f:
    ac = json.load(f)

us_ids = [u["id"] for u in ac.get("user_stories", []) if isinstance(u, dict)]

tasks = []
n = 1
for us_id in us_ids:
    if us_id in omit:
        continue
    tasks.append({
        "task_id": f"T-{n}",
        "realizes_user_stories": [us_id],
        "applies_decisions": ["spec.md#main"],
        "instructions": f"Realize {us_id}.",
        "sensors": ["tests-smoke"],
        "acceptance_criterion": f"tests/smoke/{us_id.lower()}.test.sh exits 0",
    })
    n += 1

# Always emit at least one task (synthesize_write_tasks rejects empty arrays);
# when the omit set covers every US, fall back to a placeholder task
# referencing the first non-omitted US (the test's coverage assertion will
# fail on its own and surface the issue).
if not tasks and us_ids:
    tasks.append({
        "task_id": "T-1",
        "realizes_user_stories": [us_ids[0]],
        "applies_decisions": ["spec.md#main"],
        "instructions": f"Realize {us_ids[0]} (fallback).",
        "sensors": ["tests-smoke"],
        "acceptance_criterion": "tests/smoke/fallback.test.sh exits 0",
    })

json.dump(tasks, sys.stdout, indent=2)
print()
PY
}
