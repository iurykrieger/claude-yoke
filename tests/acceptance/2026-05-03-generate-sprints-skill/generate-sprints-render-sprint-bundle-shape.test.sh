#!/usr/bin/env bash
#
# Binding Acceptance Criterion (binding contract):
#   "tests/smoke/render-bundle-shape.test.sh exits 0; every produced
#    sprint file passes the 5-H2-headings + 4-inline-labels +
#    Realizes-clause checks."
#
set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/generate-sprints/full"
SYNTHESIZE_HELPER="lib/generate-sprints/synthesize.sh"
PARTITION_HELPER="lib/generate-sprints/partition.sh"
RENDER_HELPER="lib/generate-sprints/render-bundle.sh"
STUB_HELPER="tests/acceptance/2026-05-03-generate-sprints-skill/_lib/build-stub-tasks.sh"

GAPS=()
[[ ! -f "$SYNTHESIZE_HELPER" ]] && GAPS+=("$SYNTHESIZE_HELPER")
[[ ! -f "$PARTITION_HELPER" ]] && GAPS+=("$PARTITION_HELPER")
[[ ! -f "$RENDER_HELPER" ]] && GAPS+=("$RENDER_HELPER")
if [[ "${#GAPS[@]}" -gt 0 ]]; then
  printf 'FAIL: pipeline incomplete — missing components:\n' >&2
  for g in "${GAPS[@]}"; do printf '        - %s\n' "$g" >&2; done
  exit 1
fi

WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

SLUG="2026-05-03-render-shape-fixture"
PLAN_REL=".yoke/runtime/.generate-sprints-plan.yaml"

(
  cd "$WORK_TREE"
  mkdir -p .yoke/specs .yoke/acceptance-criteria .yoke/runtime .yoke/sprints
  cp "$REPO_ROOT/$FIXTURE/spec.md" ".yoke/specs/${SLUG}.md"
  cp "$REPO_ROOT/$FIXTURE/acceptance-criteria.md" ".yoke/acceptance-criteria/${SLUG}.md"
  echo "$SLUG" > .yoke/runtime/.current

  set +e
  bash -c "
    # no set -e — preserves stderr re-emit from helpers
    source '$REPO_ROOT/lib/working-memory/paths.sh'
    source '$REPO_ROOT/lib/generate-sprints/parse-inputs.sh'
    source '$REPO_ROOT/lib/generate-sprints/plan-io.sh'
    source '$REPO_ROOT/$SYNTHESIZE_HELPER'
    source '$REPO_ROOT/$PARTITION_HELPER'
    source '$REPO_ROOT/$RENDER_HELPER'
    source '$REPO_ROOT/$STUB_HELPER'

    init_plan_file '$SLUG' || exit 1
    ensure_plan_tmp_dir || exit 1
    parse_acceptance_criteria '.yoke/acceptance-criteria/${SLUG}.md' \
      > .yoke/runtime/.generate-sprints-tmp/ac.json
    parse_spec_architecture '.yoke/specs/${SLUG}.md' \
      > .yoke/runtime/.generate-sprints-tmp/spec.json
    build_stub_tasks_json .yoke/runtime/.generate-sprints-tmp/ac.json \
      > .yoke/runtime/.generate-sprints-tmp/tasks.json
    synthesize_write_tasks \
      $PLAN_REL \
      .yoke/runtime/.generate-sprints-tmp/tasks.json \
      .yoke/runtime/.generate-sprints-tmp/ac.json
    partition_tasks $PLAN_REL || exit 1
    render_all_bundles '$SLUG' $PLAN_REL || exit 1
  " 2>"$WORK_TREE/render.stderr"
  echo $? > "$WORK_TREE/render.rc"
)

RC="$(cat "$WORK_TREE/render.rc" 2>/dev/null || echo 1)"
if [[ "$RC" -ne 0 ]]; then
  printf 'FAIL: render pipeline exited rc=%d before shape could be asserted\n' "$RC" >&2
  sed 's/^/        /' "$WORK_TREE/render.stderr" >&2 || true
  exit 1
fi

shopt -s nullglob
PRODUCED=("$WORK_TREE"/.yoke/sprints/${SLUG}-s*.md)
shopt -u nullglob

if [[ "${#PRODUCED[@]}" -eq 0 ]]; then
  printf 'FAIL: render produced zero sprint files at %s/.yoke/sprints/\n' "$WORK_TREE" >&2
  exit 1
fi

EXPECTED_H2=(
  "## Sprint objective"
  "## Sprint DoD"
  "## Tasks"
  "## Functional acceptance criteria"
  "## Sensors"
)
INLINE_LABELS=(
  "**Story:**"
  "**Technical implementation:**"
  "**Validation:**"
  "**Acceptance criterion:**"
)

FAIL=0
for sprint_file in "${PRODUCED[@]}"; do
  ACTUAL_H2_ORDER="$(grep -E '^## ' "$sprint_file" | head -5)"
  EXPECTED_H2_BLOCK="$(printf '%s\n' "${EXPECTED_H2[@]}")"
  if [[ "$ACTUAL_H2_ORDER" != "$EXPECTED_H2_BLOCK" ]]; then
    printf 'FAIL: %s — H2 headings do not match expected order\n' "$sprint_file" >&2
    printf '      expected:\n%s\n' "$EXPECTED_H2_BLOCK" | sed 's/^/        /' >&2
    printf '      actual:\n%s\n'   "$ACTUAL_H2_ORDER"  | sed 's/^/        /' >&2
    FAIL=1
    continue
  fi

  TASK_BLOCKS="$(grep -cE '^### Task ' "$sprint_file" || true)"
  if [[ "$TASK_BLOCKS" -eq 0 ]]; then
    printf 'FAIL: %s — no `### Task <ID>` subsections found\n' "$sprint_file" >&2
    FAIL=1
    continue
  fi
  for label in "${INLINE_LABELS[@]}"; do
    found="$(grep -cF "$label" "$sprint_file" || true)"
    if [[ "$found" -lt "$TASK_BLOCKS" ]]; then
      printf 'FAIL: %s — inline label `%s` appears %d times but %d task subsections present\n' \
        "$sprint_file" "$label" "$found" "$TASK_BLOCKS" >&2
      FAIL=1
    fi
  done

  STORY_LINES="$(grep -cE '^\*\*Story:\*\*' "$sprint_file" || true)"
  REALIZES_LINES="$(grep -cE '^\*\*Story:\*\*.*\(Realizes: US-[0-9]{3}(, US-[0-9]{3})*\)\s*$' "$sprint_file" || true)"
  if [[ "$STORY_LINES" -ne "$REALIZES_LINES" ]]; then
    printf 'FAIL: %s — %d Story lines but only %d carry the Realizes clause matching the regex\n' \
      "$sprint_file" "$STORY_LINES" "$REALIZES_LINES" >&2
    grep -nE '^\*\*Story:\*\*' "$sprint_file" | sed 's/^/        /' >&2 || true
    FAIL=1
    continue
  fi

  printf 'PASS: bundle shape conforms — %s\n' "$sprint_file"
done

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: generate-sprints-render-sprint-bundle-shape\n' >&2
  exit 1
fi

printf '\n--- Result ---\nPASS: generate-sprints-render-sprint-bundle-shape (%d sprint files)\n' "${#PRODUCED[@]}"
exit 0
