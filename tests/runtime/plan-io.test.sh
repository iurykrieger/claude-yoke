#!/usr/bin/env bash
# shellcheck shell=bash
#
# plan-io.test.sh — Sprint 02 / Task t04 happy-path unit test (US-003
# DoD bullet 4 + AC-003-3).
#
# Asserts that `lib/generate-sprints/plan-io.sh::init_plan_file`
# writes the empty plan stub at
# `.yoke/runtime/.generate-sprints-plan.yaml` with the four required
# top-level keys (`slug`, `generated_at`, `tasks`, `sprint_partition`)
# and that the `tasks` and `sprint_partition` arrays are emitted as
# YAML empty sequences (`!!seq` per `yq`), not as `~` / null.
# Downstream stages depend on the keys being addressable by `yq`.
#
# Also asserts that `read_plan_file` round-trips the stub and that
# `ensure_plan_tmp_dir` scaffolds the parser-output scratch directory.
#
# Test contract:
#   - exit 0 with `PASS:` lines on success.
#   - exit non-zero with `wm: plan-io violation:`-prefixed stderr
#     naming the failed assertion otherwise.
#
# This test runs against a temporary working tree (mktemp -d) so
# repeated invocations remain deterministic and never pollute the host
# project's runtime state.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: plan-io violation: %s\n' "$1" >&2
  exit 1
}

# Watchdog (per testing conventions) — guard against any subprocess
# hang. The body runs in well under 5 seconds in normal conditions.
( sleep 600 && kill -TERM $$ ) &
WATCHDOG_PID=$!
trap 'kill -TERM "$WATCHDOG_PID" 2>/dev/null || true' EXIT

# Run inside an isolated tmp dir to avoid mutating the host's
# `.yoke/runtime/` state. The plan path under plan-io.sh is relative
# to $PWD.
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"; kill -TERM "$WATCHDOG_PID" 2>/dev/null || true' EXIT

cd "$TMP_ROOT"

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/plan-io.sh"

SLUG="2026-01-01-foo"

# --- init_plan_file happy path ---------------------------------------------

init_plan_file "$SLUG" \
  || violation "init_plan_file exited non-zero on happy path"

PLAN_PATH="${TMP_ROOT}/.yoke/runtime/.generate-sprints-plan.yaml"

[[ -f "$PLAN_PATH" ]] \
  || violation "init_plan_file did not create $PLAN_PATH"

# Top-level keys via yq (preferred) or grep fallback.
if command -v yq >/dev/null 2>&1; then
  ACTUAL_SLUG="$(yq -r '.slug' "$PLAN_PATH")"
  GENERATED_AT="$(yq -r '.generated_at' "$PLAN_PATH")"
  TASKS_TYPE="$(yq -r '.tasks | type' "$PLAN_PATH")"
  TASKS_LEN="$(yq -r '.tasks | length' "$PLAN_PATH")"
  PARTITION_TYPE="$(yq -r '.sprint_partition | type' "$PLAN_PATH")"
  PARTITION_LEN="$(yq -r '.sprint_partition | length' "$PLAN_PATH")"

  [[ "$ACTUAL_SLUG" == "$SLUG" ]] \
    || violation "plan slug mismatch: expected '$SLUG', got '$ACTUAL_SLUG'"

  [[ "$GENERATED_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
    || violation "generated_at not ISO8601 UTC: '$GENERATED_AT'"

  # `yq -r '.tasks | type'` emits `!!seq` for an empty inline array.
  [[ "$TASKS_TYPE" == "!!seq" ]] \
    || violation "tasks type expected '!!seq', got '$TASKS_TYPE'"
  [[ "$TASKS_LEN" == "0" ]] \
    || violation "tasks length expected 0, got '$TASKS_LEN'"
  [[ "$PARTITION_TYPE" == "!!seq" ]] \
    || violation "sprint_partition type expected '!!seq', got '$PARTITION_TYPE'"
  [[ "$PARTITION_LEN" == "0" ]] \
    || violation "sprint_partition length expected 0, got '$PARTITION_LEN'"
else
  # Fallback shape check via grep (yq unavailable). The init_plan_file
  # output is a fixed-shape heredoc so grep is sufficient for the
  # smoke check.
  grep -qE "^slug: $SLUG$" "$PLAN_PATH" \
    || violation "plan file missing 'slug: $SLUG' line"
  grep -qE '^generated_at: [0-9]{4}-' "$PLAN_PATH" \
    || violation "plan file missing 'generated_at:' line"
  grep -qE '^tasks: \[\]$' "$PLAN_PATH" \
    || violation "plan file missing 'tasks: []' line"
  grep -qE '^sprint_partition: \[\]$' "$PLAN_PATH" \
    || violation "plan file missing 'sprint_partition: []' line"
fi

printf 'PASS: init_plan_file emits empty plan stub with !!seq arrays\n'

# --- read_plan_file round-trips --------------------------------------------

ROUND_TRIP="$(read_plan_file "$SLUG")" \
  || violation "read_plan_file exited non-zero with matching slug"

[[ -n "$ROUND_TRIP" ]] \
  || violation "read_plan_file emitted empty stdout"

echo "$ROUND_TRIP" | grep -qE "^slug: $SLUG$" \
  || violation "read_plan_file output missing slug line"

printf 'PASS: read_plan_file round-trips the stub for slug=%s\n' "$SLUG"

# --- ensure_plan_tmp_dir scaffolds the scratch directory -------------------

ensure_plan_tmp_dir \
  || violation "ensure_plan_tmp_dir exited non-zero"

[[ -d "${TMP_ROOT}/.yoke/runtime/.generate-sprints-tmp" ]] \
  || violation "ensure_plan_tmp_dir did not create the scratch dir"

printf 'PASS: ensure_plan_tmp_dir scaffolds .yoke/runtime/.generate-sprints-tmp/\n'

exit 0
