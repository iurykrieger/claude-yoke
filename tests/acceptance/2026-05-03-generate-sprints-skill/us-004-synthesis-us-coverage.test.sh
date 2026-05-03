#!/usr/bin/env bash
# criterion: AC-004-1
#
# Binding Acceptance Criterion (PRD US-004, ratified 2026-05-03T10:44:11Z):
#   "tests/smoke/synthesis-us-coverage.test.sh exits 0; the happy-path
#    branch prints `PASS: <N> USs covered by <M> tasks` (M ≥ N)."
#
# Sprint-3 anchors:
#   - sprint task s03-t01 acceptance criterion: bash exits 0 AND prints
#     `PASS: 4 USs covered by N tasks` (N integer ≥ 4).
#   - functional acceptance criterion id: synthesis-task-list-non-empty.
#
# Sr Eng's Sprint-3 contract: the LLM-driven synthesis step lives
# *inside* the skill body; the deterministic spine
# (`lib/generate-sprints/synthesize.sh`) ships
# `synthesize_validate_inputs` (input shape gate) and
# `synthesize_write_tasks <plan> <tasks-json> <ac-json>` (post-LLM
# validate + plan write + US-coverage enforcement). We exercise the
# spine with a deterministic stub of the LLM emission (`_lib/build-stub-tasks.sh`).
#
# Then-clause (binding):
#   GIVEN the synthesis happy-path fixture (4 USs in
#   tests/fixtures/generate-sprints/synthesis/happy/)
#   WHEN the deterministic spine is exercised end-to-end against it
#   THEN
#     (a) `synthesize_write_tasks` MUST exit 0;
#     (b) the produced plan's `tasks` array MUST be non-empty AND
#         have length ≥ N (number of USs in the fixture);
#     (c) every US-NNN heading from the AC MUST appear in at least
#         one task's `realizes_user_stories`.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/generate-sprints/synthesis/happy"
SYNTHESIZE_HELPER="lib/generate-sprints/synthesize.sh"
STUB_HELPER="tests/acceptance/2026-05-03-generate-sprints-skill/_lib/build-stub-tasks.sh"

if [[ ! -f "$FIXTURE/acceptance-criteria.md" || ! -f "$FIXTURE/spec.md" ]]; then
  printf 'FAIL: synthesis happy-path fixture missing at %s\n' "$FIXTURE" >&2
  exit 1
fi
if [[ ! -f "$SYNTHESIZE_HELPER" ]]; then
  printf 'FAIL: %s missing — Sprint 3 task s03-t01 mandates the synthesis spine helper\n' "$SYNTHESIZE_HELPER" >&2
  exit 1
fi

N_US="$(grep -cE '^### US-[0-9]{3}' "$FIXTURE/acceptance-criteria.md" || true)"
if [[ "$N_US" -lt 4 ]]; then
  printf 'FAIL: fixture must carry ≥ 4 USs; found %d in %s\n' \
    "$N_US" "$FIXTURE/acceptance-criteria.md" >&2
  exit 1
fi

WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

SLUG="2026-05-03-synthesis-happy-fixture"
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
    parse_spec_architecture '.yoke/specs/${SLUG}.md' \
      > .yoke/runtime/.generate-sprints-tmp/spec.json

    synthesize_validate_inputs \
      .yoke/runtime/.generate-sprints-tmp/ac.json \
      .yoke/runtime/.generate-sprints-tmp/spec.json

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
  printf 'FAIL: synthesize_write_tasks exited rc=%d on the happy-path fixture\n' "$RC" >&2
  printf '      stderr:\n' >&2
  sed 's/^/        /' "$WORK_TREE/synth.stderr" >&2 || true
  exit 1
fi

PLAN="$WORK_TREE/$PLAN_REL"
if [[ ! -f "$PLAN" ]]; then
  printf 'FAIL: synthesize_write_tasks did not produce %s\n' "$PLAN_REL" >&2
  exit 1
fi

# Count tasks deterministically via PyYAML.
M_TASKS="$(python3 - "$PLAN" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    plan = yaml.safe_load(f) or {}
tasks = plan.get("tasks") or []
print(len(tasks))
PY
)"

if [[ "$M_TASKS" -lt "$N_US" ]]; then
  printf 'FAIL: AC-004-1 violated — produced plan has %d tasks but fixture has %d USs (M ≥ N invariant)\n' \
    "$M_TASKS" "$N_US" >&2
  exit 1
fi

# Coverage check: every US must appear in at least one task's
# realizes_user_stories array.
declare -a MISSING=()
for us_id in $(grep -oE '^### US-[0-9]{3}' "$FIXTURE/acceptance-criteria.md" | awk '{print $2}'); do
  hit="$(python3 - "$PLAN" "$us_id" <<'PY'
import sys, yaml
plan_path, us = sys.argv[1], sys.argv[2]
with open(plan_path) as f:
    plan = yaml.safe_load(f) or {}
hits = 0
for t in plan.get("tasks") or []:
    if us in (t.get("realizes_user_stories") or []):
        hits += 1
print(hits)
PY
  )"
  if [[ "$hit" -lt 1 ]]; then
    MISSING+=("$us_id")
  fi
done

if [[ "${#MISSING[@]}" -gt 0 ]]; then
  printf 'FAIL: AC-004-1 coverage invariant violated — USs not realized: %s\n' "${MISSING[*]}" >&2
  exit 1
fi

printf 'PASS: %d USs covered by %d tasks\n' "$N_US" "$M_TASKS"
printf '\n--- Result ---\nPASS: us-004-synthesis-us-coverage\n'
exit 0
