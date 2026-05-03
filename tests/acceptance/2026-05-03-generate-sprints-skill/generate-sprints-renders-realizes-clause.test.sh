#!/usr/bin/env bash
#
# Binding Acceptance Criterion (binding contract):
#   "Every produced `**Story:**` line ends with a clause matching
#    `\(Realizes: US-[0-9]{3}(, US-[0-9]{3})*\)`."
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

SLUG="2026-05-03-realizes-clause-fixture"
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
    build_stub_tasks_json .yoke/runtime/.generate-sprints-tmp/ac.json \
      > .yoke/runtime/.generate-sprints-tmp/tasks.json
    synthesize_write_tasks \
      $PLAN_REL \
      .yoke/runtime/.generate-sprints-tmp/tasks.json \
      .yoke/runtime/.generate-sprints-tmp/ac.json
    partition_tasks $PLAN_REL || exit 1
    render_all_bundles '$SLUG' $PLAN_REL || exit 1
  " 2>"$WORK_TREE/pipe.stderr"
  echo $? > "$WORK_TREE/pipe.rc"
)

RC="$(cat "$WORK_TREE/pipe.rc" 2>/dev/null || echo 1)"
if [[ "$RC" -ne 0 ]]; then
  printf 'FAIL: pipeline exited rc=%d before realizes-clause regex could be checked\n' "$RC" >&2
  sed 's/^/        /' "$WORK_TREE/pipe.stderr" >&2 || true
  exit 1
fi

shopt -s nullglob
PRODUCED=("$WORK_TREE"/.yoke/sprints/${SLUG}-s*.md)
shopt -u nullglob

if [[ "${#PRODUCED[@]}" -eq 0 ]]; then
  printf 'FAIL: pipeline produced zero sprint files; AC-005-3 cannot be checked\n' >&2
  exit 1
fi

REGEX='\(Realizes: US-[0-9]{3}(, US-[0-9]{3})*\)'
FAIL=0
for sprint_file in "${PRODUCED[@]}"; do
  STORY_TOTAL="$(grep -cE '^\*\*Story:\*\*' "$sprint_file" || true)"
  if [[ "$STORY_TOTAL" -eq 0 ]]; then
    printf 'FAIL: %s — no Story lines found\n' "$sprint_file" >&2
    FAIL=1
    continue
  fi
  STORY_OK="$(grep -cE "^\\*\\*Story:\\*\\*.*${REGEX}\\s*$" "$sprint_file" || true)"
  if [[ "$STORY_OK" -ne "$STORY_TOTAL" ]]; then
    printf 'FAIL: %s — %d Story lines but only %d match the binding regex `%s`\n' \
      "$sprint_file" "$STORY_TOTAL" "$STORY_OK" "$REGEX" >&2
    grep -nE '^\*\*Story:\*\*' "$sprint_file" | sed 's/^/        /' >&2 || true
    FAIL=1
    continue
  fi
  if grep -qE '\(Realizes: UC-' "$sprint_file"; then
    printf 'FAIL: %s — legacy `(Realizes: UC-...)` shape detected; binding shape is US-NNN\n' "$sprint_file" >&2
    FAIL=1
    continue
  fi
  printf 'PASS: %s — every Story line ends with the binding Realizes clause\n' "$sprint_file"
done

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: generate-sprints-renders-realizes-clause\n' >&2
  exit 1
fi

printf '\n--- Result ---\nPASS: generate-sprints-renders-realizes-clause\n'
exit 0
