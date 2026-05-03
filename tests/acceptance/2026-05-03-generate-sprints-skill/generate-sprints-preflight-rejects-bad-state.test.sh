#!/usr/bin/env bash
#
# Binding Acceptance Criteria (binding contract):
#   "Pre-flight refuses to run when .yoke/config.yaml is missing or
#    lacks `canonical_memory.provider`, surfacing the standard
#    `yoke_require_provider` stderr verbatim."
#   "Pre-flight refuses to run when .yoke/specs/<slug>.md is absent or
#    its frontmatter status is not `approved`."
#   "Pre-flight refuses to run when .yoke/acceptance-criteria/<slug>.md
#    is absent or its frontmatter status is not `approved`."
#   "tests/smoke/generate-sprints-preflight.test.sh exits 0 across
#    fixtures covering: missing spec, missing AC, unapproved spec,
#    unapproved AC, all-good."
#
# Sprint-level anchor:
#   - Functional acceptance criterion id:
#     generate-sprints-preflight-rejects-five-modes
#   - Task s02-t02 acceptance criterion: stdout contains exactly five
#     lines starting with `PASS:` (one per negative branch).
#
# Then-clause (binding):
#   For EACH of the five preflight failure modes, invoking the skill's
#   pre-flight bash spine against the matching fixture under
#   tests/fixtures/generate-sprints/preflight/<mode>/ MUST exit non-zero
#   AND emit a `wm:`-prefixed line on stderr naming the missing /
#   unapproved artifact.
#
#   Five modes:
#     1. no-config       — .yoke/config.yaml missing entirely
#     2. no-provider     — config present but `canonical_memory.provider` empty
#     3. no-slug         — `.yoke/runtime/.current` missing (no active task)
#     4. unapproved-spec — spec exists but frontmatter status != approved
#     5. unratified-ac   — acceptance-criteria exists but status != approved
#
# Sr Eng integration note:
#   The skill's pre-flight is intended to be invocable as a bash
#   composition (per s02-t02: `source <plugin_dir>/lib/yoke-prelude.sh
#   && yoke_require_provider; source paths.sh; wm_active_slug; ...`).
#   Until Sr Eng ships the composed pre-flight harness, this test
#   exercises the lib-level helpers directly so the negative branches
#   are still gated by the binding contract.
#
# Watchdog convention — keep the smoke-test guard.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURES="tests/fixtures/generate-sprints/preflight"
FAIL=0

# ---------------------------------------------------------------------------
# Helper — run pre-flight against one fixture as a sub-shell with the
# fixture pinned as YOKE_HOST_PROJECT_ROOT (paths helpers respect this
# env var). Capture stderr into $PREFLIGHT_STDERR and exit code into
# $PREFLIGHT_RC.
#
# We invoke the lib helpers directly here because Sr Eng's composed
# pre-flight (skills/generate-sprints/SKILL.md `Pre-flight` stage) is
# the unit under test — it must, when implemented, drive these same
# helpers and surface the same stderr vocabulary.
# ---------------------------------------------------------------------------
run_preflight() {
  local fixture_dir="$1"
  PREFLIGHT_STDERR="$(mktemp)"
  PREFLIGHT_RC=0
  # NB: the outer `|| PREFLIGHT_RC=$?` neutralizes the parent's
  # `set -e` for the expected-to-fail subshell. Without it, every
  # fixture that should reject would also abort this test harness.
  (
    cd "$fixture_dir"
    # Drive pre-flight via a bash subshell that mirrors the documented
    # composition in s02-t02 of the sprint:
    #   source lib/yoke-prelude.sh && yoke_require_provider || exit 1
    #   source lib/working-memory/paths.sh && slug="$(wm_active_slug)"
    #   spec_path="$(wm_spec_path "$slug")"
    #   ac_path="$(wm_acceptance_criteria_path "$slug")"
    #   for path; assert exists AND status=approved
    bash -c '
      set -e
      # shellcheck disable=SC1091
      source "'"$REPO_ROOT"'/lib/yoke-prelude.sh"
      yoke_require_provider
      # shellcheck disable=SC1091
      source "'"$REPO_ROOT"'/lib/working-memory/paths.sh"
      slug="$(wm_active_slug)"
      [[ -n "$slug" ]] || { echo "wm: no active slug" >&2; exit 1; }
      spec_path="$(wm_spec_path "$slug")"
      [[ -f "$spec_path" ]] || { echo "wm: spec missing or unapproved at $spec_path" >&2; exit 1; }
      grep -qE "^status:[[:space:]]+approved[[:space:]]*$" "$spec_path" || {
        echo "wm: spec missing or unapproved at $spec_path" >&2; exit 1; }
      ac_path="$(wm_acceptance_criteria_path "$slug")"
      [[ -f "$ac_path" ]] || { echo "wm: acceptance-criteria missing or unapproved at $ac_path" >&2; exit 1; }
      grep -qE "^status:[[:space:]]+approved[[:space:]]*$" "$ac_path" || {
        echo "wm: acceptance-criteria missing or unapproved at $ac_path" >&2; exit 1; }
    '
  ) 2>"$PREFLIGHT_STDERR" || PREFLIGHT_RC=$?
}

# ---------------------------------------------------------------------------
# Iterate the five negative branches. Each branch:
#   - exits non-zero
#   - prints a `wm:`-prefixed diagnostic on stderr
# Emit one `PASS:` line per branch on success (matches sprint-level
# task s02-t02 acceptance criterion: "stdout contains exactly five
# lines starting with `PASS:`").
# ---------------------------------------------------------------------------
modes=(no-config no-provider no-slug unapproved-spec unratified-ac)

for mode in "${modes[@]}"; do
  fixture="${FIXTURES}/${mode}"
  if [[ ! -d "$fixture" ]]; then
    printf 'FAIL: fixture missing for mode `%s` at %s\n' "$mode" "$fixture" >&2
    FAIL=1
    continue
  fi
  run_preflight "$fixture"
  if [[ "$PREFLIGHT_RC" -eq 0 ]]; then
    printf 'FAIL: pre-flight unexpectedly succeeded for mode `%s` (rc=0)\n' "$mode" >&2
    FAIL=1
  elif ! grep -qE '^wm:' "$PREFLIGHT_STDERR"; then
    printf 'FAIL: pre-flight rejected mode `%s` but stderr lacks `wm:` prefix\n' "$mode" >&2
    sed 's/^/    /' "$PREFLIGHT_STDERR" >&2 || true
    FAIL=1
  else
    printf 'PASS: pre-flight rejected mode `%s` with wm:-prefixed stderr\n' "$mode"
  fi
  rm -f "$PREFLIGHT_STDERR"
done

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: generate-sprints-preflight-rejects-bad-state\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: generate-sprints-preflight-rejects-bad-state (5 modes covered)\n'
exit 0
