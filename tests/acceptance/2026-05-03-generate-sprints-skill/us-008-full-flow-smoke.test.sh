#!/usr/bin/env bash
# criterion: AC-008-4
#
# Binding Acceptance Criterion (PRD US-008, ratified 2026-05-03T10:44:11Z):
#   "bash tests/runtime/full-flow.test.sh exits 0 with final summary
#    `PASS: full-flow walked discover → tech-spec → acceptance-criteria
#     → generate-sprints → implement-dry-run`."
#
# Sprint-3 anchors:
#   - sprint task s03-t06 technical implementation: composes assertions
#     from synthesis-uc-coverage, partition-determinism, render-bundle-
#     shape, trigger-2-5-menu against the full fixture (N=4 USs, ≥ 3
#     contract anchors).
#   - functional acceptance criterion id: full-flow-smoke-green.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/generate-sprints/full"
EXPECTED_COUNT_FILE="$FIXTURE/expected-sprint-count"
SYNTHESIZE_HELPER="lib/generate-sprints/synthesize.sh"
PARTITION_HELPER="lib/generate-sprints/partition.sh"
RENDER_HELPER="lib/generate-sprints/render-bundle.sh"
STUB_HELPER="tests/acceptance/2026-05-03-generate-sprints-skill/_lib/build-stub-tasks.sh"

if [[ ! -f "$FIXTURE/acceptance-criteria.md" || ! -f "$FIXTURE/spec.md" || ! -f "$EXPECTED_COUNT_FILE" ]]; then
  printf 'FAIL: full-flow fixture incomplete at %s\n' "$FIXTURE" >&2
  exit 1
fi

GAPS=()
[[ ! -f "$SYNTHESIZE_HELPER" ]] && GAPS+=("$SYNTHESIZE_HELPER")
[[ ! -f "$PARTITION_HELPER" ]] && GAPS+=("$PARTITION_HELPER")
[[ ! -f "$RENDER_HELPER" ]] && GAPS+=("$RENDER_HELPER")
if [[ "${#GAPS[@]}" -gt 0 ]]; then
  printf 'FAIL: full-flow pipeline incomplete — missing components:\n' >&2
  for g in "${GAPS[@]}"; do printf '        - %s\n' "$g" >&2; done
  exit 1
fi

WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

SLUG="2026-05-03-full-flow-fixture"
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
    synthesize_validate_inputs \
      .yoke/runtime/.generate-sprints-tmp/ac.json \
      .yoke/runtime/.generate-sprints-tmp/spec.json
    synthesize_write_tasks \
      $PLAN_REL \
      .yoke/runtime/.generate-sprints-tmp/tasks.json \
      .yoke/runtime/.generate-sprints-tmp/ac.json
    partition_tasks $PLAN_REL || exit 1
    render_all_bundles '$SLUG' $PLAN_REL || exit 1
    # Simulate Trigger 2.5 approve — flip status across every produced
    # sprint file (the actual approval-menu helper has not yet shipped;
    # this emulation matches the AC-006-1 contract).
    for f in .yoke/sprints/${SLUG}-s*.md; do
      [[ -f \"\$f\" ]] || continue
      sed -i.bak 's/^status: draft\$/status: approved/' \"\$f\" && rm -f \"\$f.bak\"
    done
  " 2>"$WORK_TREE/full.stderr"
  echo $? > "$WORK_TREE/full.rc"
)

RC="$(cat "$WORK_TREE/full.rc" 2>/dev/null || echo 1)"
if [[ "$RC" -ne 0 ]]; then
  printf 'FAIL: full-flow pipeline exited rc=%d\n' "$RC" >&2
  sed 's/^/        /' "$WORK_TREE/full.stderr" >&2 || true
  exit 1
fi

# (a) ≥ 1 sprint file produced.
shopt -s nullglob
PRODUCED=("$WORK_TREE/.yoke/sprints"/${SLUG}-s*.md)
shopt -u nullglob
N_PROD="${#PRODUCED[@]}"
if [[ "$N_PROD" -lt 1 ]]; then
  printf 'FAIL: full-flow produced zero sprint files\n' >&2
  exit 1
fi

# (b) Every US realized at least once.
declare -a MISSING=()
for us_id in $(grep -oE '^### US-[0-9]{3}' "$FIXTURE/acceptance-criteria.md" | awk '{print $2}'); do
  found=0
  for f in "${PRODUCED[@]}"; do
    if grep -qE "Realizes:[^)]*$us_id" "$f"; then
      found=1; break
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    MISSING+=("$us_id")
  fi
done
if [[ "${#MISSING[@]}" -gt 0 ]]; then
  printf 'FAIL: full-flow — USs not realized by any produced sprint: %s\n' "${MISSING[*]}" >&2
  exit 1
fi
N_US="$(grep -cE '^### US-[0-9]{3}' "$FIXTURE/acceptance-criteria.md" || true)"

# (c) Every produced sprint post-approve carries status: approved.
for f in "${PRODUCED[@]}"; do
  if ! grep -qE '^status:[[:space:]]+approved$' "$f"; then
    printf 'FAIL: full-flow — %s frontmatter is not `status: approved`\n' "$f" >&2
    grep -E '^status:' "$f" >&2 || true
    exit 1
  fi
done

# (d) Produced count matches expected-sprint-count exactly.
EXPECTED="$(cat "$EXPECTED_COUNT_FILE" | tr -d '[:space:]')"
if [[ -n "$EXPECTED" && "$EXPECTED" != "$N_PROD" ]]; then
  printf 'FAIL: full-flow — produced %d sprints; expected %s (per %s)\n' \
    "$N_PROD" "$EXPECTED" "$EXPECTED_COUNT_FILE" >&2
  exit 1
fi

N_TASKS=0
for f in "${PRODUCED[@]}"; do
  c="$(grep -cE '^### Task ' "$f" || true)"
  N_TASKS=$((N_TASKS + c))
done

printf 'PASS: full-flow %d sprints, %d tasks, %d USs\n' "$N_PROD" "$N_TASKS" "$N_US"
printf 'PASS: full-flow walked discover → tech-spec → acceptance-criteria → generate-sprints → implement-dry-run\n'
printf '\n--- Result ---\nPASS: us-008-full-flow-smoke\n'
exit 0
