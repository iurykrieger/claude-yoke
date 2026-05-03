#!/usr/bin/env bash
# shellcheck shell=bash
#
# synthesize.test.sh — Sprint 03 / Task t01 happy-path unit test
# (US-004 synthesis-stage validators, AC-004-3 + FR-1).
#
# Asserts that `lib/generate-sprints/synthesize.sh`:
#   1. `synthesize_validate_inputs` accepts the well-formed JSON
#      intermediates emitted by `parse_acceptance_criteria` and
#      `parse_spec_architecture`.
#   2. `synthesize_write_tasks` validates the LLM-emitted tasks JSON,
#      enforces the per-task schema, rejects per-persona forks (FR-1),
#      enforces US-coverage when an AC JSON is provided.
#   3. The plan file post-write carries the tasks array sorted by
#      placeholder ordinal (T-1, T-2, ...).
#
# Test contract:
#   - exit 0 with `PASS:` lines on success.
#   - exit non-zero with `wm: synthesize violation:`-prefixed stderr.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: synthesize violation: %s\n' "$1" >&2
  exit 1
}

# Watchdog.
( sleep 600 && kill -TERM $$ ) &
WATCHDOG_PID=$!
trap 'kill -TERM "$WATCHDOG_PID" 2>/dev/null || true' EXIT

# Isolated tmp dir.
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"; kill -TERM "$WATCHDOG_PID" 2>/dev/null || true' EXIT

cd "$TMP_ROOT"

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/plan-io.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/synthesize.sh"

SLUG="2026-01-01-baz"

# --- Bootstrap: write the JSON intermediates ---------------------------------

mkdir -p "${TMP_ROOT}/.yoke/runtime/.generate-sprints-tmp"
AC_JSON="${TMP_ROOT}/.yoke/runtime/.generate-sprints-tmp/ac.json"
SPEC_JSON="${TMP_ROOT}/.yoke/runtime/.generate-sprints-tmp/spec.json"
TASKS_JSON="${TMP_ROOT}/.yoke/runtime/.generate-sprints-tmp/tasks.json"

cat > "$AC_JSON" <<'JSON'
{
  "user_stories": [
    {
      "id": "US-001",
      "title": "First",
      "story": "As a user...",
      "dod": ["thing 1"],
      "acceptance_criteria": [{"id": "AC-001-1", "text": "first"}]
    },
    {
      "id": "US-002",
      "title": "Second",
      "story": "As a user...",
      "dod": ["thing 2"],
      "acceptance_criteria": [{"id": "AC-002-1", "text": "second"}]
    }
  ],
  "functional_requirements": [{"id": "FR-1", "text": "no per-persona forks"}],
  "sensor_pool": ["lint", "tests-runtime"]
}
JSON

cat > "$SPEC_JSON" <<'JSON'
{
  "objective": "Ship the synthesizer happy-path validation.",
  "contracts": ["paths.sh", "templates/sprint.md"],
  "dependencies": {
    "external_services": [],
    "internal_prior_work": [],
    "cross_team_coordination": []
  }
}
JSON

# --- synthesize_validate_inputs accepts well-formed intermediates -----------

synthesize_validate_inputs "$AC_JSON" "$SPEC_JSON" \
  || violation "synthesize_validate_inputs failed on well-formed JSON"

printf 'PASS: synthesize_validate_inputs accepts well-formed inputs\n'

# --- Bootstrap: write the LLM-emitted tasks JSON (well-formed) --------------

cat > "$TASKS_JSON" <<'JSON'
[
  {
    "task_id": "T-2",
    "realizes_user_stories": ["US-002"],
    "applies_decisions": ["paths.sh"],
    "instructions": "Wire the second user story.",
    "sensors": ["tests-runtime"],
    "acceptance_criterion": "Second story shipped."
  },
  {
    "task_id": "T-1",
    "realizes_user_stories": ["US-001"],
    "applies_decisions": ["templates/sprint.md"],
    "instructions": "Wire the first user story.",
    "sensors": ["lint"],
    "acceptance_criterion": "First story shipped."
  }
]
JSON

init_plan_file "$SLUG" >/dev/null

PLAN_PATH="${TMP_ROOT}/.yoke/runtime/.generate-sprints-plan.yaml"

synthesize_write_tasks "$PLAN_PATH" "$TASKS_JSON" "$AC_JSON" \
  || violation "synthesize_write_tasks failed on well-formed tasks JSON"

# Verify the plan file carries the tasks sorted by placeholder ordinal.
TASK_IDS="$(yq -r '.tasks[].task_id' "$PLAN_PATH" | tr '\n' ',' | sed 's/,$//')"
[[ "$TASK_IDS" == "T-1,T-2" ]] \
  || violation "tasks not sorted by placeholder ordinal: $TASK_IDS"

printf 'PASS: synthesize_write_tasks merged tasks sorted by placeholder ordinal\n'

# --- US-coverage enforcement: reject when a US is unrealised ----------------

cat > "$TASKS_JSON" <<'JSON'
[
  {
    "task_id": "T-1",
    "realizes_user_stories": ["US-001"],
    "applies_decisions": [],
    "instructions": "Only US-001 is realised.",
    "sensors": [],
    "acceptance_criterion": "Just US-001."
  }
]
JSON

init_plan_file "$SLUG" >/dev/null

# Capture the failing call's stderr. set -e would otherwise exit on
# the non-zero rc; disable it for the negative-branch assertions.
set +e
STDERR_OUT="$(synthesize_write_tasks "$PLAN_PATH" "$TASKS_JSON" "$AC_JSON" 2>&1)"
RC=$?
set -e
[[ "$RC" -ne 0 ]] \
  || violation "synthesize_write_tasks accepted an unrealised US"

echo "$STDERR_OUT" | grep -q "wm: unrealized USs: US-002" \
  || violation "expected stderr 'wm: unrealized USs: US-002', got: $STDERR_OUT"

printf 'PASS: US-coverage enforced (US-002 unrealised → wm: unrealized USs)\n'

# --- FR-1 enforcement: per-persona forks rejected ---------------------------

cat > "$TASKS_JSON" <<'JSON'
[
  {
    "task_id": "T-1",
    "realizes_user_stories": ["US-001", "US-002"],
    "applies_decisions": [],
    "instructions": "Do the thing.\n\n**For Sr Eng:** code\n\n**For Sr QA:** tests",
    "sensors": [],
    "acceptance_criterion": "Done."
  }
]
JSON

init_plan_file "$SLUG" >/dev/null

set +e
STDERR_OUT="$(synthesize_write_tasks "$PLAN_PATH" "$TASKS_JSON" "$AC_JSON" 2>&1)"
RC=$?
set -e
[[ "$RC" -ne 0 ]] \
  || violation "synthesize_write_tasks accepted a per-persona fork"

echo "$STDERR_OUT" | grep -q "per-persona fork" \
  || violation "expected stderr to flag the per-persona fork, got: $STDERR_OUT"

printf 'PASS: FR-1 enforced (per-persona fork → rejected)\n'

exit 0
