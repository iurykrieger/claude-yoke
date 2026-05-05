#!/usr/bin/env bash
# criterion: AC-003-2
#
# AC-003-2 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "Every existing PRD-backed task in the project's test corpus
#    completes the full PRD → tech-spec → AC → implement → canonize
#    chain end-to-end with no path-resolution errors — measured
#    against a regression suite of ≥ 5 representative PRD-backed
#    scenarios under tests/regression/phase1-backward-compat/."
#
# Sprint scope (s02-t03 + s02-t06): the cycle's regression deliverable
# is ≥ 1 representative scenario for Sprint 02; the remaining scenarios
# are deferred to Sprint 03's smoke-test task per the cycle's scope
# direction. This acceptance test pins the Sprint-02 representative
# scenario as the binding judgment surface — the broader 5-scenario
# suite under tests/regression/phase1-backward-compat/ is Sr Eng's
# implementation lane (s02-t06) and is exercised separately by the
# smoke runner.
#
# Representative scenario covered here:
#
#   "PRD-backed Phase-1 archive resolves to its PRD path after the
#    `wm_prd_path → wm_phase1_artifact_path` migration; the migrated
#    skill prelude (read site that previously called `wm_prd_path`)
#    receives the same path string it received pre-migration; no
#    skill outside skills/discover/ and skills/fix/ holds a residual
#    `wm_prd_path` read."
#
# Observable conditions tested:
#   (1) `wm_phase1_artifact_path` symbol is exported by paths.sh
#       (pre-flight; missing helper short-circuits).
#   (2) On a fixture host project where ONLY `.yoke/prds/<slug>.md`
#       exists for <slug>, `wm_phase1_artifact_path "<slug>"` returns
#       exactly `.yoke/prds/<slug>.md` with rc=0 and empty stderr.
#       Pins the resolver's "PRD-backed task continues to resolve"
#       half (the path-resolution-error-free guarantee for a real
#       PRD-backed run).
#   (3) The same call honours the active-slug fallback when called
#       without an argument and `.yoke/runtime/.current` carries the
#       slug. This pins the resolver's symmetry with the rest of the
#       paths.sh helpers — every downstream skill calls
#       `wm_phase1_artifact_path` (no arg, active-slug-driven) per
#       the migration contract; a regression in that path silently
#       breaks every skill.
#   (4) `wm_prd_path` itself still resolves the same string it always
#       did (the migration of call sites is ADDITIVE — it does NOT
#       break the helper). `/yoke:discover` and `/yoke:fix` still
#       hold their `wm_prd_path` reads per the no-direct-prd-path
#       sensor's allow-list.
#   (5) The regression-suite directory `tests/regression/phase1-backward-compat/`
#       exists. The directory's population beyond Sprint 02's seed
#       scenario is Sprint 03's lane — but the directory itself MUST
#       exist after Sprint 02 so Sprint 03's tasks have a target.
#       Soft-pass: a missing directory is a `PARTIAL` signal, not a
#       hard fail (Sr Eng's lane this cycle is the resolver, not the
#       full ≥5-scenario suite per cycle scope).

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
#   tests/acceptance/<slug>/ac-003-2.test.sh -> ../../..
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

PATHS_LIB="$REPO_ROOT/lib/working-memory/paths.sh"
if [[ ! -f "$PATHS_LIB" ]]; then
  err "missing paths.sh at $PATHS_LIB"
  harness::summary
fi

VALID_SLUG="2026-04-25-phase-persona-rebalance"
EXPECTED_PRD_PATH=".yoke/prds/${VALID_SLUG}.md"

# ---------------------------------------------------------------------------
# Case (1) — wm_phase1_artifact_path symbol is exported by paths.sh.
# ---------------------------------------------------------------------------
TMP_PRECHECK=$(mktemp -d)
set +e
(
  cd "$TMP_PRECHECK"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  declare -F wm_phase1_artifact_path >/dev/null
)
PRECHECK_RC=$?
set -e
rm -rf "$TMP_PRECHECK"

if [[ "$PRECHECK_RC" -eq 0 ]]; then
  pass "(1) wm_phase1_artifact_path is exported by lib/working-memory/paths.sh"
else
  err "(1) wm_phase1_artifact_path is NOT exported by lib/working-memory/paths.sh — declare -F returned $PRECHECK_RC"
  harness::summary
fi

# ---------------------------------------------------------------------------
# Case (2) — only-PRD branch resolves to the PRD path.
#
# Real backward-compat scenario: every Phase-1 archive in the test
# corpus today is PRD-only. After the migration, every downstream
# skill calls `wm_phase1_artifact_path "<slug>"` and MUST receive
# `.yoke/prds/<slug>.md` for those slugs.
# ---------------------------------------------------------------------------
TMP_PRD=$(mktemp -d)
T2_OUT="$TMP_PRD/stdout"
T2_ERR="$TMP_PRD/stderr"

mkdir -p "$TMP_PRD/.yoke/prds" "$TMP_PRD/.yoke/fixes"
printf '# PRD body for %s\n\nIntroduction.\n' "$VALID_SLUG" \
  > "$TMP_PRD/.yoke/prds/${VALID_SLUG}.md"

set +e
(
  cd "$TMP_PRD"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "$VALID_SLUG"
) >"$T2_OUT" 2>"$T2_ERR"
T2_RC=$?
set -e

T2_STDOUT="$(cat "$T2_OUT")"
T2_STDERR="$(cat "$T2_ERR")"

if [[ "$T2_RC" -eq 0 && "$T2_STDOUT" == "$EXPECTED_PRD_PATH" && -z "$T2_STDERR" ]]; then
  pass "(2) wm_phase1_artifact_path '$VALID_SLUG' (only-PRD) -> '$EXPECTED_PRD_PATH' (rc=0, stderr empty)"
else
  err "(2) wm_phase1_artifact_path only-PRD branch mismatch rc=$T2_RC stdout='$T2_STDOUT' stderr='$T2_STDERR' expected='$EXPECTED_PRD_PATH'"
fi

rm -rf "$TMP_PRD"

# ---------------------------------------------------------------------------
# Case (3) — active-slug fallback resolves to the same PRD path.
#
# Every downstream skill currently calls a path helper without an
# argument so the helper falls back to wm_active_slug. After the
# migration the call shape is `wm_phase1_artifact_path` with no arg.
# Pin that the active-slug fallback works the same way — a regression
# here breaks every migrated skill silently.
# ---------------------------------------------------------------------------
TMP_ACTIVE=$(mktemp -d)
T3_OUT="$TMP_ACTIVE/stdout"
T3_ERR="$TMP_ACTIVE/stderr"

mkdir -p "$TMP_ACTIVE/.yoke/prds" \
         "$TMP_ACTIVE/.yoke/fixes" \
         "$TMP_ACTIVE/.yoke/runtime"
printf '# PRD body for %s\n' "$VALID_SLUG" \
  > "$TMP_ACTIVE/.yoke/prds/${VALID_SLUG}.md"
printf '%s' "$VALID_SLUG" > "$TMP_ACTIVE/.yoke/runtime/.current"

set +e
(
  cd "$TMP_ACTIVE"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path
) >"$T3_OUT" 2>"$T3_ERR"
T3_RC=$?
set -e

T3_STDOUT="$(cat "$T3_OUT")"
T3_STDERR="$(cat "$T3_ERR")"

if [[ "$T3_RC" -eq 0 && "$T3_STDOUT" == "$EXPECTED_PRD_PATH" && -z "$T3_STDERR" ]]; then
  pass "(3) wm_phase1_artifact_path (no arg, active=$VALID_SLUG) -> '$EXPECTED_PRD_PATH' (rc=0, stderr empty)"
else
  err "(3) wm_phase1_artifact_path active-slug fallback mismatch rc=$T3_RC stdout='$T3_STDOUT' stderr='$T3_STDERR' expected='$EXPECTED_PRD_PATH'"
fi

rm -rf "$TMP_ACTIVE"

# ---------------------------------------------------------------------------
# Case (4) — wm_prd_path itself remains intact post-migration.
#
# The migration of call sites in `/yoke:tech-spec`,
# `/yoke:acceptance-criteria`, `/yoke:generate-sprints`,
# `/yoke:implement`, `/yoke:canonize`, and `/yoke:status` from
# `wm_prd_path` to `wm_phase1_artifact_path` is ADDITIVE — the helper
# itself is not deleted. `/yoke:discover` and `/yoke:fix` still call
# `wm_prd_path` directly per the no-direct-prd-path sensor's
# allow-list (s02-t04). Pin the helper still echoes its documented
# string so a future drift that deletes it does not slip through.
# ---------------------------------------------------------------------------
TMP_HELPER=$(mktemp -d)
T4_OUT="$TMP_HELPER/stdout"
T4_ERR="$TMP_HELPER/stderr"

set +e
(
  cd "$TMP_HELPER"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_prd_path "$VALID_SLUG"
) >"$T4_OUT" 2>"$T4_ERR"
T4_RC=$?
set -e

T4_STDOUT="$(cat "$T4_OUT")"
T4_STDERR="$(cat "$T4_ERR")"

if [[ "$T4_RC" -eq 0 && "$T4_STDOUT" == "$EXPECTED_PRD_PATH" && -z "$T4_STDERR" ]]; then
  pass "(4) wm_prd_path '$VALID_SLUG' -> '$EXPECTED_PRD_PATH' (rc=0, stderr empty) — pre-migration helper intact"
else
  err "(4) wm_prd_path regressed post-migration rc=$T4_RC stdout='$T4_STDOUT' stderr='$T4_STDERR' expected='$EXPECTED_PRD_PATH'"
fi

rm -rf "$TMP_HELPER"

# ---------------------------------------------------------------------------
# Case (5) — regression suite directory exists.
#
# Sprint 02's deliverable is the directory + a representative seed
# scenario (this acceptance test counts as the seed). Sprint 03 is
# scoped to populate ≥ 5 PRD-backed scenario fixtures per AC-003-2's
# full-text contract. The directory must exist after Sprint 02 so
# Sprint 03's smoke runner has a target — pin the directory's presence.
# ---------------------------------------------------------------------------
REGRESSION_DIR="$REPO_ROOT/tests/regression/phase1-backward-compat"
if [[ -d "$REGRESSION_DIR" ]]; then
  pass "(5) tests/regression/phase1-backward-compat/ exists (Sprint 02 deliverable)"
else
  err "(5) tests/regression/phase1-backward-compat/ does not exist — Sprint 02 deliverable per s02-t06"
fi

harness::summary
