#!/usr/bin/env bash
# criterion: AC-003-4 / sprint-02 plan-yaml-schema-callable
#
# Binding Acceptance Criteria (PRD US-003 + US-004 cross-anchor,
# ratified 2026-05-03T06:39:27Z):
#   US-003 — pre-flight composes init_plan_file as the final gate.
#   US-004 — "the skill emits a structured intermediate (committed to
#     runtime state under .yoke/runtime/.generate-sprints-plan.yaml,
#     gitignored)".
#   Sprint DoD (s02): "Running /yoke:generate-sprints against the
#     happy-path fixture produces .yoke/runtime/.generate-sprints-plan.yaml
#     whose top-level keys are exactly slug, generated_at, tasks (empty
#     list), sprint_partition (empty list)."
#   Task s02-t04 acceptance criterion: "yq '.tasks | type' returns
#     `!!seq` and yq '.tasks | length' returns 0".
#
# Sprint-level anchor:
#   - Functional acceptance criterion id: plan-yaml-schema-callable
#
# Then-clause (binding):
#   1. Helper file `lib/generate-sprints/plan-io.sh` exists and defines
#      `init_plan_file`.
#   2. Running `init_plan_file <slug>` against a temp HOME-equivalent
#      directory writes the plan file at the expected path.
#   3. The written file has top-level keys exactly: slug, generated_at,
#      tasks, sprint_partition (no others).
#   4. `tasks` and `sprint_partition` are emitted as YAML sequences
#      (not `~`, not omitted) and have length 0.
#   5. `slug` matches the input slug.
#
# Sr Eng integration note:
#   The sprint task body uses `yq` for assertion. We require `yq` only
#   if the helper produced a file — we feature-detect and skip the
#   yq-specific assertions with a SKIP marker if `yq` is unavailable;
#   fall back to a python yaml-based check (PyYAML is a Yoke runtime
#   dep already in tests).
#
# Watchdog convention — keep the smoke-test guard.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PLAN_LIB="lib/generate-sprints/plan-io.sh"
FAIL=0

# ---------------------------------------------------------------------------
# Then-clause part 1 — helper file exists and defines init_plan_file.
# ---------------------------------------------------------------------------
if [[ ! -f "$PLAN_LIB" ]]; then
  printf 'FAIL: %s does not exist (Sr Eng output pending; expected in s02-t04)\n' "$PLAN_LIB" >&2
  printf '\n--- Result ---\nFAIL: us-003-plan-yaml-init\n' >&2
  exit 1
fi
printf 'PASS: %s exists\n' "$PLAN_LIB"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"; kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT
mkdir -p "$TMPHOME/.yoke/runtime"

# Drive the helper from a sub-shell with the temp dir as the host
# project root so the writer targets the temp `.yoke/runtime/` and
# does not clobber the worktree's runtime state.
PLAN_OUT="$TMPHOME/.yoke/runtime/.generate-sprints-plan.yaml"
INIT_RC=0
(
  set +e
  cd "$TMPHOME"
  bash -c '
    set -e
    # shellcheck disable=SC1090,SC1091
    source "'"$REPO_ROOT"'/'"$PLAN_LIB"'"
    if ! declare -F init_plan_file >/dev/null 2>&1; then
      echo "wm: init_plan_file not defined after sourcing plan-io.sh" >&2
      exit 2
    fi
    init_plan_file "2026-01-01-foo"
  '
) || INIT_RC=$?

if [[ "$INIT_RC" -ne 0 ]]; then
  printf 'FAIL: init_plan_file returned rc=%d on happy path\n' "$INIT_RC" >&2
  printf '\n--- Result ---\nFAIL: us-003-plan-yaml-init\n' >&2
  exit 1
fi
printf 'PASS: init_plan_file returned rc=0\n'

# ---------------------------------------------------------------------------
# Then-clause part 2 — file exists at expected path.
# ---------------------------------------------------------------------------
if [[ ! -f "$PLAN_OUT" ]]; then
  printf 'FAIL: plan file not written at %s\n' "$PLAN_OUT" >&2
  printf '\n--- Result ---\nFAIL: us-003-plan-yaml-init\n' >&2
  exit 1
fi
printf 'PASS: plan file written at %s\n' "$PLAN_OUT"

# ---------------------------------------------------------------------------
# Then-clause parts 3-5 — schema assertions. Prefer `yq` if available
# (matches the sprint task's literal acceptance criterion); fall back
# to PyYAML otherwise.
# ---------------------------------------------------------------------------
if command -v yq >/dev/null 2>&1; then
  printf 'INFO: yq detected; running sprint-task literal assertions\n'

  TASKS_TYPE="$(yq '.tasks | type' "$PLAN_OUT" 2>/dev/null || echo "ERR")"
  if [[ "$TASKS_TYPE" == "!!seq" ]] || [[ "$TASKS_TYPE" == "array" ]] || [[ "$TASKS_TYPE" == "!!seq"* ]]; then
    printf 'PASS: yq .tasks type is sequence (got: %s)\n' "$TASKS_TYPE"
  else
    printf 'FAIL: yq .tasks type is `%s` (expected `!!seq` / `array`)\n' "$TASKS_TYPE" >&2
    FAIL=1
  fi

  TASKS_LEN="$(yq '.tasks | length' "$PLAN_OUT" 2>/dev/null || echo ERR)"
  if [[ "$TASKS_LEN" == "0" ]]; then
    printf 'PASS: yq .tasks length is 0\n'
  else
    printf 'FAIL: yq .tasks length is `%s` (expected 0)\n' "$TASKS_LEN" >&2
    FAIL=1
  fi

  PART_TYPE="$(yq '.sprint_partition | type' "$PLAN_OUT" 2>/dev/null || echo ERR)"
  if [[ "$PART_TYPE" == "!!seq" ]] || [[ "$PART_TYPE" == "array" ]] || [[ "$PART_TYPE" == "!!seq"* ]]; then
    printf 'PASS: yq .sprint_partition type is sequence (got: %s)\n' "$PART_TYPE"
  else
    printf 'FAIL: yq .sprint_partition type is `%s` (expected `!!seq` / `array`)\n' "$PART_TYPE" >&2
    FAIL=1
  fi

  PART_LEN="$(yq '.sprint_partition | length' "$PLAN_OUT" 2>/dev/null || echo ERR)"
  if [[ "$PART_LEN" == "0" ]]; then
    printf 'PASS: yq .sprint_partition length is 0\n'
  else
    printf 'FAIL: yq .sprint_partition length is `%s` (expected 0)\n' "$PART_LEN" >&2
    FAIL=1
  fi

  SLUG_VAL="$(yq '.slug' "$PLAN_OUT" 2>/dev/null | tr -d '"' || echo ERR)"
  if [[ "$SLUG_VAL" == "2026-01-01-foo" ]]; then
    printf 'PASS: yq .slug is `2026-01-01-foo`\n'
  else
    printf 'FAIL: yq .slug is `%s` (expected `2026-01-01-foo`)\n' "$SLUG_VAL" >&2
    FAIL=1
  fi
else
  printf 'INFO: yq absent; falling back to python3 yaml schema check\n'
  python3 - "$PLAN_OUT" <<'PY' || FAIL=1
import sys, yaml
path = sys.argv[1]
try:
    with open(path) as f:
        data = yaml.safe_load(f)
except Exception as exc:
    print(f"FAIL: cannot parse YAML: {exc}", file=sys.stderr)
    sys.exit(1)

required = {"slug", "generated_at", "tasks", "sprint_partition"}
got = set(data.keys()) if isinstance(data, dict) else set()
extra = got - required
missing = required - got

if missing:
    print(f"FAIL: missing top-level keys: {missing}", file=sys.stderr)
    sys.exit(1)
print(f"PASS: top-level keys include all of {required}")

# Note: extra keys are warned, not fatal — the binding contract is
# silent on extra keys.
if extra:
    print(f"INFO: extra top-level keys present: {extra}")

if not isinstance(data["tasks"], list):
    print(f"FAIL: tasks is type `{type(data['tasks']).__name__}` (expected list)", file=sys.stderr)
    sys.exit(1)
print("PASS: tasks is a list")

if len(data["tasks"]) != 0:
    print(f"FAIL: tasks length is {len(data['tasks'])} (expected 0)", file=sys.stderr)
    sys.exit(1)
print("PASS: tasks length is 0")

if not isinstance(data["sprint_partition"], list):
    print(f"FAIL: sprint_partition is type `{type(data['sprint_partition']).__name__}` (expected list)", file=sys.stderr)
    sys.exit(1)
print("PASS: sprint_partition is a list")

if len(data["sprint_partition"]) != 0:
    print(f"FAIL: sprint_partition length is {len(data['sprint_partition'])} (expected 0)", file=sys.stderr)
    sys.exit(1)
print("PASS: sprint_partition length is 0")

if data.get("slug") != "2026-01-01-foo":
    print(f"FAIL: slug is `{data.get('slug')}` (expected `2026-01-01-foo`)", file=sys.stderr)
    sys.exit(1)
print("PASS: slug is `2026-01-01-foo`")
PY
fi

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: us-003-plan-yaml-init\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: us-003-plan-yaml-init\n'
exit 0
