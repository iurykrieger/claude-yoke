#!/usr/bin/env bash
#
# Binding Acceptance Criterion (binding contract):
#   "Each task in the produced plan carries a non-empty
#    `realizes_user_stories` array; the array entries match the regex
#    `^US-[0-9]{3}$`."
#
set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/generate-sprints/synthesis/happy"
SYNTHESIZE_HELPER="lib/generate-sprints/synthesize.sh"
STUB_HELPER="tests/acceptance/2026-05-03-generate-sprints-skill/_lib/build-stub-tasks.sh"

if [[ ! -f "$SYNTHESIZE_HELPER" ]]; then
  printf 'FAIL: %s missing — Sprint 3 task s03-t01 mandates one\n' "$SYNTHESIZE_HELPER" >&2
  exit 1
fi

WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

SLUG="2026-05-03-realizes-fixture"
PLAN_REL=".yoke/runtime/.generate-sprints-plan.yaml"

(
  cd "$WORK_TREE"
  mkdir -p .yoke/specs .yoke/acceptance-criteria .yoke/runtime
  cp "$REPO_ROOT/$FIXTURE/spec.md" ".yoke/specs/${SLUG}.md"
  cp "$REPO_ROOT/$FIXTURE/acceptance-criteria.md" ".yoke/acceptance-criteria/${SLUG}.md"
  echo "$SLUG" > .yoke/runtime/.current

  set +e
  bash -c "
    # no set -e — preserves stderr re-emit from helpers
    source '$REPO_ROOT/lib/generate-sprints/parse-inputs.sh'
    source '$REPO_ROOT/lib/generate-sprints/plan-io.sh'
    source '$REPO_ROOT/$SYNTHESIZE_HELPER'
    source '$REPO_ROOT/$STUB_HELPER'
    init_plan_file '$SLUG' || exit 1
    ensure_plan_tmp_dir || exit 1
    parse_acceptance_criteria '.yoke/acceptance-criteria/${SLUG}.md' \
      > .yoke/runtime/.generate-sprints-tmp/ac.json
    build_stub_tasks_json .yoke/runtime/.generate-sprints-tmp/ac.json \
      > .yoke/runtime/.generate-sprints-tmp/tasks.json
    synthesize_write_tasks \
      $PLAN_REL \
      .yoke/runtime/.generate-sprints-tmp/tasks.json \
      .yoke/runtime/.generate-sprints-tmp/ac.json
  " 2>"$WORK_TREE/synth.stderr"
  echo $? > "$WORK_TREE/synth.rc"
)

RC="$(cat "$WORK_TREE/synth.rc" 2>/dev/null || echo 1)"
if [[ "$RC" -ne 0 ]]; then
  printf 'FAIL: synthesize_write_tasks exited rc=%d before realizes-array shape could be asserted\n' "$RC" >&2
  sed 's/^/        /' "$WORK_TREE/synth.stderr" >&2 || true
  exit 1
fi

PLAN="$WORK_TREE/$PLAN_REL"
if [[ ! -f "$PLAN" ]]; then
  printf 'FAIL: synthesize_write_tasks did not produce plan at %s\n' "$PLAN" >&2
  exit 1
fi

# Inspect every task's realizes_user_stories array via PyYAML.
python3 - "$PLAN" <<'PY'
import re
import sys
import yaml

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    plan = yaml.safe_load(f) or {}

us_re = re.compile(r"^US-\d{3}$")
tasks = plan.get("tasks") or []
failures = []

if not tasks:
    failures.append("plan has zero tasks — synthesise stage produced no entries")

for t in tasks:
    tid = t.get("task_id", "<no-id>")
    realizes = t.get("realizes_user_stories")
    if not isinstance(realizes, list) or not realizes:
        failures.append(f"task `{tid}` has empty/missing realizes_user_stories array")
        continue
    for entry in realizes:
        if not isinstance(entry, str) or not us_re.match(entry):
            failures.append(
                f"task `{tid}` carries malformed realizes entry "
                f"`{entry}` (expected ^US-[0-9]{{3}}$)"
            )

if failures:
    for f in failures:
        print(f"FAIL: {f}", file=sys.stderr)
    sys.exit(1)

print(f"PASS: every realizes_user_stories array non-empty AND US-NNN-shaped across {len(tasks)} tasks")
sys.exit(0)
PY
RC=$?
if [[ "$RC" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: generate-sprints-synthesis-realizes-array-shape\n' >&2
  exit 1
fi

printf '\n--- Result ---\nPASS: generate-sprints-synthesis-realizes-array-shape\n'
exit 0
