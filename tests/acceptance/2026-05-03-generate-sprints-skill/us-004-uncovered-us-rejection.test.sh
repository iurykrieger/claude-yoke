#!/usr/bin/env bash
# criterion: AC-004-2
#
# Binding Acceptance Criterion (PRD US-004, ratified 2026-05-03T10:44:11Z):
#   "The uncovered-US negative branch causes the skill to abort non-zero
#    with stderr `wm: unrealized USs: US-<NNN>[, US-<MMM>]`."
#
# Sprint-3 anchors:
#   - sprint task s03-t01 acceptance criterion (negative branch).
#   - functional acceptance criterion id: synthesis-us-coverage-enforced.
#
# Sr Eng's Sprint-3 contract: `synthesize_write_tasks <plan> <tasks-json>
# <ac-json>` enforces US-coverage by aborting non-zero with the literal
# `wm: unrealized USs: US-NNN[, US-MMM]` when the LLM-emitted tasks
# leave any AC US unrealized. We exercise the validator with a stub
# tasks JSON that deliberately omits US-003 (the engineered orphan in
# the uncovered-US fixture).
#
# Then-clause (binding):
#   GIVEN the uncovered-US fixture and a tasks JSON omitting US-003
#   WHEN `synthesize_write_tasks` runs
#   THEN it MUST exit non-zero AND emit on stderr a line matching
#   `^wm: unrealized USs: US-003`.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/generate-sprints/synthesis/uncovered-us"
SYNTHESIZE_HELPER="lib/generate-sprints/synthesize.sh"
STUB_HELPER="tests/acceptance/2026-05-03-generate-sprints-skill/_lib/build-stub-tasks.sh"

if [[ ! -f "$FIXTURE/acceptance-criteria.md" || ! -f "$FIXTURE/spec.md" ]]; then
  printf 'FAIL: uncovered-US fixture missing at %s\n' "$FIXTURE" >&2
  exit 1
fi
if [[ ! -f "$SYNTHESIZE_HELPER" ]]; then
  printf 'FAIL: %s missing — Sprint 3 task s03-t01 mandates the synthesis spine\n' "$SYNTHESIZE_HELPER" >&2
  exit 1
fi

WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

SLUG="2026-05-03-uncovered-us-fixture"
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
    # Build a stub tasks JSON that deliberately omits US-003.
    build_stub_tasks_json .yoke/runtime/.generate-sprints-tmp/ac.json US-003 \
      > .yoke/runtime/.generate-sprints-tmp/tasks.json
    synthesize_write_tasks \
      $PLAN_REL \
      .yoke/runtime/.generate-sprints-tmp/tasks.json \
      .yoke/runtime/.generate-sprints-tmp/ac.json
  " 2>"$WORK_TREE/synth.stderr"
  echo $? > "$WORK_TREE/synth.rc"
)

RC="$(cat "$WORK_TREE/synth.rc" 2>/dev/null || echo 0)"

if [[ "$RC" -eq 0 ]]; then
  printf 'FAIL: AC-004-2 violated — synthesize_write_tasks exited 0 with US-003 deliberately uncovered\n' >&2
  exit 1
fi

if ! grep -qE '^wm: unrealized USs:[[:space:]]+US-[0-9]{3}' "$WORK_TREE/synth.stderr"; then
  printf 'FAIL: AC-004-2 violated — stderr lacks `^wm: unrealized USs: US-NNN` literal\n' >&2
  printf '      stderr captured:\n' >&2
  sed 's/^/        /' "$WORK_TREE/synth.stderr" >&2 || true
  exit 1
fi

if ! grep -qE 'US-003' "$WORK_TREE/synth.stderr"; then
  printf 'FAIL: AC-004-2 violated — `wm: unrealized USs:` does not name US-003 (the engineered orphan)\n' >&2
  printf '      stderr captured:\n' >&2
  sed 's/^/        /' "$WORK_TREE/synth.stderr" >&2 || true
  exit 1
fi

printf 'PASS: synthesize_write_tasks aborted on uncovered US-003 with documented stderr literal\n'
printf '\n--- Result ---\nPASS: us-004-uncovered-us-rejection\n'
exit 0
