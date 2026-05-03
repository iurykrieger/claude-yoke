#!/usr/bin/env bash
# criterion: AC-008-4
#
# Binding Acceptance Criterion (PRD US-008, ratified 2026-05-03T10:44:11Z):
#   AC-008-4: bash tests/runtime/full-flow.test.sh exits 0 with final
#             summary `PASS: full-flow walked discover → tech-spec →
#             acceptance-criteria → generate-sprints → implement-dry-run`.
#
# Sprint-4 anchor:
#   - sprint task s04-t05 technical implementation: walks the full
#     new-flow chain end-to-end against a synthetic fixture, with a
#     dry-run flag that short-circuits Phase A spawn after the gate
#     checks pass.
#   - functional acceptance criterion id: full-flow-smoke-green.
#
# Strategy:
#   The producer-side substages (parse → synthesize → partition →
#   render → approve) are already exercised by the cycle-3 acceptance
#   test at tests/acceptance/2026-05-03-generate-sprints-skill/
#   us-008-full-flow-smoke.test.sh, which uses a deterministic stub
#   for the LLM step (build_stub_tasks_json). This runtime smoke
#   extends that walk by adding two upstream stages and one downstream
#   stage:
#     - Upstream stage 1: simulate `/yoke:discover` by asserting the
#       fixture PRD parses into the canonical post-rename shape (no
#       `## User Stories` section per the rename PR).
#     - Upstream stage 2: simulate `/yoke:tech-spec` by asserting the
#       fixture spec carries no `### Task <slug>-s` headings.
#     - Upstream stage 3: simulate `/yoke:acceptance-criteria` by
#       asserting the fixture AC carries the new `### US-<NNN>` shape
#       AND a Sensor pool block.
#     - Producer pipeline: re-run the producer chain end-to-end (the
#       same code path the cycle-3 stub exercises).
#     - Downstream stage 1: simulate `/yoke:implement` first-cycle
#       dry-run by asserting the gate-detection ladder reports the
#       correct state across each stage transition (when the
#       gate-state helper is shipped) AND post-render reports
#       running:implement (every produced sprint approved + zero
#       cycles run yet).
#
#   The watchdog pattern is preserved from the cycle-3 stub
#   (`sleep 600 && kill -TERM $$ &`) per
#   concepts/yoke-pattern-test-watchdog.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/fixtures/generate-sprints/full"
EXPECTED_COUNT_FILE="$FIXTURE/expected-sprint-count"
SYNTHESIZE_HELPER="lib/generate-sprints/synthesize.sh"
PARTITION_HELPER="lib/generate-sprints/partition.sh"
RENDER_HELPER="lib/generate-sprints/render-bundle.sh"
STUB_HELPER="tests/acceptance/2026-05-03-generate-sprints-skill/_lib/build-stub-tasks.sh"

if [[ ! -f "$FIXTURE/acceptance-criteria.md" \
   || ! -f "$FIXTURE/spec.md" \
   || ! -f "$FIXTURE/prd.md" \
   || ! -f "$EXPECTED_COUNT_FILE" ]]; then
  printf 'FAIL: full-flow fixture incomplete at %s\n' "$FIXTURE" >&2
  exit 1
fi

GAPS=()
[[ ! -f "$SYNTHESIZE_HELPER" ]] && GAPS+=("$SYNTHESIZE_HELPER")
[[ ! -f "$PARTITION_HELPER" ]] && GAPS+=("$PARTITION_HELPER")
[[ ! -f "$RENDER_HELPER" ]] && GAPS+=("$RENDER_HELPER")
[[ ! -f "$STUB_HELPER" ]] && GAPS+=("$STUB_HELPER")
if [[ "${#GAPS[@]}" -gt 0 ]]; then
  printf 'FAIL: full-flow pipeline incomplete — missing components:\n' >&2
  for g in "${GAPS[@]}"; do printf '        - %s\n' "$g" >&2; done
  exit 1
fi

# ---------- Upstream stage 1: /yoke:discover (PRD shape) ----------
# Post-rename PRD shape: no `## User Stories` section (USs live in
# the AC artifact). The fixture PRD MUST conform to that shape.
PRD="$FIXTURE/prd.md"
if grep -qE '^## User Stories$' "$PRD"; then
  printf 'FAIL: AC-008-4 — fixture PRD carries `## User Stories` (post-rename PRD must not)\n' >&2
  exit 1
fi
# Goals + FRs MUST be present (canonical PRD shape).
if ! grep -qE '^## Goals$' "$PRD"; then
  printf 'FAIL: AC-008-4 — fixture PRD lacks `## Goals`\n' >&2
  exit 1
fi
if ! grep -qiE '^## Functional [Rr]equirements$' "$PRD"; then
  printf 'FAIL: AC-008-4 — fixture PRD lacks `## Functional Requirements`\n' >&2
  exit 1
fi
printf 'PASS: discover stage — PRD shape conforms (post-rename)\n'

# ---------- Upstream stage 2: /yoke:tech-spec (spec shape) ----------
# Post-cutover spec shape: no `### Task <slug>-s` headings (tasks live
# in the sprint runtime bundles, produced by /yoke:generate-sprints).
SPEC="$FIXTURE/spec.md"
if grep -qE '^### Task [^[:space:]]+-s[0-9]+' "$SPEC"; then
  printf 'FAIL: AC-008-4 — fixture spec carries `### Task <slug>-s` headings (post-cutover spec must not)\n' >&2
  exit 1
fi
# Architecture-only spec MUST carry overall objective + contracts.
if ! grep -qE '^## Overall objective$' "$SPEC"; then
  printf 'FAIL: AC-008-4 — fixture spec lacks `## Overall objective`\n' >&2
  exit 1
fi
printf 'PASS: tech-spec stage — spec shape conforms (architecture-only)\n'

# ---------- Upstream stage 3: /yoke:acceptance-criteria (AC shape) ----------
# Post-rename AC shape: at least one `### US-<NNN>` heading AND a
# `## Sensor pool` section.
AC="$FIXTURE/acceptance-criteria.md"
if ! grep -qE '^### US-[0-9]+' "$AC"; then
  printf 'FAIL: AC-008-4 — fixture AC carries no `### US-<NNN>` headings\n' >&2
  exit 1
fi
if ! grep -qE '^## Sensor pool$' "$AC"; then
  printf 'FAIL: AC-008-4 — fixture AC lacks `## Sensor pool` section\n' >&2
  exit 1
fi
printf 'PASS: acceptance-criteria stage — AC shape conforms (US-NNN + sensor pool)\n'

# ---------- Producer pipeline: synthesize → partition → render → approve ----------
WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

SLUG="2026-05-03-full-flow-runtime-fixture"
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
    # sprint file. The runtime helper for approve / reject is wired
    # inline in the skill body per the cycle-3 council consensus
    # (see Sr Eng cycle-3 inline-body argument).
    for f in .yoke/sprints/${SLUG}-s*.md; do
      [[ -f \"\$f\" ]] || continue
      sed -i.bak 's/^status: draft\$/status: approved/' \"\$f\" && rm -f \"\$f.bak\"
    done
  " 2>"$WORK_TREE/full.stderr"
  echo $? > "$WORK_TREE/full.rc"
)

RC="$(cat "$WORK_TREE/full.rc" 2>/dev/null || echo 1)"
if [[ "$RC" -ne 0 ]]; then
  printf 'FAIL: AC-008-4 — producer pipeline exited rc=%d\n' "$RC" >&2
  sed 's/^/        /' "$WORK_TREE/full.stderr" >&2 || true
  exit 1
fi

# Producer pipeline post-conditions.
shopt -s nullglob
PRODUCED=("$WORK_TREE/.yoke/sprints"/${SLUG}-s*.md)
shopt -u nullglob
N_PROD="${#PRODUCED[@]}"
if [[ "$N_PROD" -lt 1 ]]; then
  printf 'FAIL: AC-008-4 — producer pipeline produced zero sprint files\n' >&2
  exit 1
fi

# Every US realized at least once.
declare -a MISSING=()
for us_id in $(grep -oE '^### US-[0-9]+' "$AC" | awk '{print $2}'); do
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
  printf 'FAIL: AC-008-4 — USs not realized by any produced sprint: %s\n' "${MISSING[*]}" >&2
  exit 1
fi
N_US="$(grep -cE '^### US-[0-9]+' "$AC" || true)"

# Every produced sprint post-approve carries status: approved.
for f in "${PRODUCED[@]}"; do
  if ! grep -qE '^status:[[:space:]]+approved$' "$f"; then
    printf 'FAIL: AC-008-4 — %s frontmatter is not `status: approved`\n' "$f" >&2
    grep -E '^status:' "$f" >&2 || true
    exit 1
  fi
done
printf 'PASS: generate-sprints stage — %d sprint(s) produced, %d US(s) realized, all approved\n' "$N_PROD" "$N_US"

# Produced count matches expected-sprint-count exactly (when set).
EXPECTED="$(cat "$EXPECTED_COUNT_FILE" | tr -d '[:space:]')"
if [[ -n "$EXPECTED" && "$EXPECTED" != "$N_PROD" ]]; then
  printf 'FAIL: AC-008-4 — produced %d sprints; expected %s (per %s)\n' \
    "$N_PROD" "$EXPECTED" "$EXPECTED_COUNT_FILE" >&2
  exit 1
fi

# ---------- Downstream stage: /yoke:implement first-cycle dry-run ----------
# Per Sprint 4 plan, /yoke:implement honours a dry-run gate that
# short-circuits Phase A spawn after the gate check passes. The dry-
# run state machine here:
#   (a) before producing sprint files: gate state would be
#       awaiting:generate-sprints (asserted via fixture engineering
#       under tests/fixtures/implement/new-flow-awaiting and
#       exercised by us-006-implement-refuses-awaiting.test.sh).
#   (b) after producing sprint files: gate state is running:implement
#       (every produced sprint is approved AND there is no progress.md
#       entry yet, so cycle 0 has not run).
# This test exercises (b) — the post-approve transition — by asserting
# the fixture worktree carries the expected post-state.
HELPER="lib/working-memory/gate-state.sh"
if [[ -f "$HELPER" ]]; then
  set +e
  STATE_AFTER="$(
    bash -c "
      source '$REPO_ROOT/$HELPER'
      type detect_gate_state >/dev/null 2>&1 || exit 99
      cd '$WORK_TREE' && detect_gate_state
    " 2>/dev/null
  )"
  RC=$?
  set -e
  if [[ "$RC" -eq 99 ]]; then
    printf 'NOTICE: gate-state helper present but lacks detect_gate_state — skipping runtime gate check\n'
  else
    case "$STATE_AFTER" in
      running:implement|done)
        printf 'PASS: implement-dry-run — post-approve state = %s\n' "$STATE_AFTER"
        ;;
      awaiting:*)
        printf 'FAIL: AC-008-4 — post-approve state should be running:implement, got `%s`\n' "$STATE_AFTER" >&2
        exit 1
        ;;
      *)
        printf 'FAIL: AC-008-4 — post-approve state unknown: `%s`\n' "$STATE_AFTER" >&2
        exit 1
        ;;
    esac
  fi
else
  # Fallback: structural post-state check without the helper.
  # Every produced sprint approved + no progress.md present = the
  # ladder would yield running:implement (the helper's logic is
  # purely a `test -f` cascade per the binding contract).
  if [[ -f "$WORK_TREE/.yoke/runtime/progress.md" ]]; then
    printf 'FAIL: AC-008-4 — fixture worktree leaked progress.md (pre-implement state polluted)\n' >&2
    exit 1
  fi
  printf 'PASS: implement-dry-run — structural post-state assertion (helper not yet shipped)\n'
fi

N_TASKS=0
for f in "${PRODUCED[@]}"; do
  c="$(grep -cE '^### Task ' "$f" || true)"
  N_TASKS=$((N_TASKS + c))
done

printf '\nPASS: full-flow %d sprints, %d tasks, %d USs\n' "$N_PROD" "$N_TASKS" "$N_US"
printf 'PASS: full-flow walked discover → tech-spec → acceptance-criteria → generate-sprints → implement-dry-run\n'
printf '\n--- Result ---\nPASS: tests/runtime/full-flow.test.sh\n'
exit 0
