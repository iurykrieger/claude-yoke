#!/usr/bin/env bash
#
# Binding Acceptance Criterion (binding contract):
#   "Frontmatter `traceability` contains both spec and AC paths
#    (semicolon-separated)."
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

SLUG="2026-05-03-trace-fixture"
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
  printf 'FAIL: pipeline exited rc=%d before frontmatter could be checked\n' "$RC" >&2
  sed 's/^/        /' "$WORK_TREE/pipe.stderr" >&2 || true
  exit 1
fi

shopt -s nullglob
PRODUCED=("$WORK_TREE"/.yoke/sprints/${SLUG}-s*.md)
shopt -u nullglob

if [[ "${#PRODUCED[@]}" -eq 0 ]]; then
  printf 'FAIL: pipeline produced zero sprint files; AC-005-4 cannot be checked\n' >&2
  exit 1
fi

EXPECTED_SPEC=".yoke/specs/${SLUG}.md"
EXPECTED_AC=".yoke/acceptance-criteria/${SLUG}.md"

FAIL=0
for sprint_file in "${PRODUCED[@]}"; do
  FRONT="$(awk '
    /^---$/ { count++; next }
    count == 1 { print }
    count == 2 { exit }
  ' "$sprint_file")"

  TRACE_LINE="$(echo "$FRONT" | grep -E '^traceability:' || true)"
  if [[ -z "$TRACE_LINE" ]]; then
    printf 'FAIL: %s — frontmatter has no `traceability:` field\n' "$sprint_file" >&2
    FAIL=1
    continue
  fi
  if ! echo "$TRACE_LINE" | grep -qF "$EXPECTED_SPEC"; then
    printf 'FAIL: %s — `traceability:` does not contain `%s`\n' "$sprint_file" "$EXPECTED_SPEC" >&2
    printf '      actual: %s\n' "$TRACE_LINE" >&2
    FAIL=1
    continue
  fi
  if ! echo "$TRACE_LINE" | grep -qF "$EXPECTED_AC"; then
    printf 'FAIL: %s — `traceability:` does not contain `%s`\n' "$sprint_file" "$EXPECTED_AC" >&2
    printf '      actual: %s\n' "$TRACE_LINE" >&2
    FAIL=1
    continue
  fi
  printf 'PASS: %s — traceability cites both spec and AC paths\n' "$sprint_file"
done

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: generate-sprints-traceability-frontmatter\n' >&2
  exit 1
fi

printf '\n--- Result ---\nPASS: generate-sprints-traceability-frontmatter\n'
exit 0
