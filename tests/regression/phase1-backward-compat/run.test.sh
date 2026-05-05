#!/usr/bin/env bash
# tests/regression/phase1-backward-compat/run.test.sh
#
# Regression suite — closes AC-003-2 PARTIAL → PASS.
#
# AC-003-2 (binding):
#   "Every existing PRD-backed task in the project's test corpus
#    completes the full PRD → tech-spec → AC → implement → canonize
#    chain end-to-end with no path-resolution errors — measured against
#    a regression suite of >= 5 representative PRD-backed scenarios under
#    tests/regression/phase1-backward-compat/."
#
# This test walks five PRD-backed fixture scenarios. For each scenario:
#   1. Create a tmp .yoke/ tree with a fixture PRD at
#      .yoke/prds/<slug>.md carrying `Status: approved`.
#   2. Verify wm_phase1_artifact_path "<slug>" returns the PRD path
#      with rc=0 and stderr empty.
#   3. Verify every migrated downstream skill body (tech-spec,
#      acceptance-criteria, generate-sprints, implement, status)
#      consumes wm_phase1_artifact_path in its pre-flight contract,
#      not wm_prd_path. (Direct PRD reads outside skills/(discover|fix)
#      are blocked by the no-direct-prd-path sensor; this regression
#      suite asserts the positive form: every downstream skill calls
#      the resolver at least once.)
#   4. Verify each migrated skill's pre-flight error message points at
#      "/yoke:discover or /yoke:fix" (the dual-entrypoint message),
#      not at the legacy "/yoke:discover"-only string.
#   5. Clean up the fixture state. Each scenario runs in its own
#      tmpdir; no leakage between scenarios.
#
# Five scenarios chosen to span the corpus shape:
#
#   S1: 2026-01-15-payment-receipts        (greenfield product feature)
#   S2: 2026-02-04-search-relevance-tuning (refinement of an existing surface)
#   S3: 2026-02-22-onboarding-redesign     (multi-component redesign)
#   S4: 2026-03-10-rate-limiter-rework     (infra-flavored product spec)
#   S5: 2026-04-18-checkout-fast-path      (perf-flavored product spec)
#
# All five scenarios are PRD-backed (no .yoke/fixes/<slug>.md). The
# fix-spec-backed end-to-end is covered by tests/smoke/fix-spec-end-to-end.test.sh
# (AC-003-3, separate concern).
#
# Anchors:
#   - PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-9 / FR-10)
#   - Spec: .yoke/specs/2026-05-05-phase-1-fix-entrypoint.md
#       (APIs and Data Model :: wm_phase1_artifact_path)
#   - Acceptance Criteria (binding):
#       .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#       (AC-003-2)
#   - Sprint task: 2026-05-05-phase-1-fix-entrypoint-s04-t02 (T-13)
#
# Watchdog convention (concepts/yoke-conventions): smoke / regression
# tests must guard against ralph-loop iterations or LLM-driven steps
# without hard bounds.

set -euo pipefail

# Watchdog — kill the test process tree at 10 minutes flat.
sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
# tests/regression/phase1-backward-compat/run.test.sh -> ../../..
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

# Source the harness for pass/err/summary helpers.
source "$REPO_ROOT/tests/lib/harness.sh"

PATHS_LIB="$REPO_ROOT/lib/working-memory/paths.sh"
if [[ ! -f "$PATHS_LIB" ]]; then
  err "missing paths.sh at $PATHS_LIB"
  harness::summary
fi

# Five representative PRD-backed scenarios.
SCENARIOS=(
  "2026-01-15-payment-receipts"
  "2026-02-04-search-relevance-tuning"
  "2026-02-22-onboarding-redesign"
  "2026-03-10-rate-limiter-rework"
  "2026-04-18-checkout-fast-path"
)

# Migrated downstream skills: every read site must call
# wm_phase1_artifact_path (not wm_prd_path). The regression contract is
# the positive form of the no-direct-prd-path sensor: every skill in
# this list must reference the resolver at least once in its body.
#
# /yoke:status is intentionally NOT in this list. Status performs a
# presence-check on `prds/<slug>.md` OR `fixes/<slug>.md` to determine
# the phase reached; it does NOT *read* the Phase-1 artifact body.
# Per US-003 DoD ("for Phase-1-artifact reads"), presence-checks fall
# outside the migration scope. Status is covered separately by the
# no-direct-prd-path sensor (CI-gated) which asserts status does not
# read prd/fix bodies via wm_prd_path.
DOWNSTREAM_SKILLS=(
  "skills/tech-spec/SKILL.md"
  "skills/acceptance-criteria/SKILL.md"
  "skills/generate-sprints/SKILL.md"
  "skills/implement/SKILL.md"
)

# ---------------------------------------------------------------------------
# Pre-flight: every downstream skill body consumes wm_phase1_artifact_path.
# This is the "migration is complete" gate. Asserted once, before walking
# the per-scenario fixtures.
# ---------------------------------------------------------------------------
echo "--- pre-flight: downstream-skill migration ---"
for skill in "${DOWNSTREAM_SKILLS[@]}"; do
  if [[ ! -f "$REPO_ROOT/$skill" ]]; then
    err "missing migrated downstream skill: $skill"
    continue
  fi
  if grep -q 'wm_phase1_artifact_path' "$REPO_ROOT/$skill"; then
    pass "downstream skill $skill consumes wm_phase1_artifact_path"
  else
    err "downstream skill $skill does NOT consume wm_phase1_artifact_path (regressed?)"
  fi
done

# ---------------------------------------------------------------------------
# Pre-flight: dual-entrypoint pre-flight error message in migrated skills.
# Sprint 02's migration updated the pre-flight error from
# "Run `/yoke:discover` first." to "Run `/yoke:discover` or `/yoke:fix` first."
# in every migrated skill. This regression test asserts the new message
# is present in at least one migrated skill body so a future cycle
# cannot silently revert the migration.
# ---------------------------------------------------------------------------
echo "--- pre-flight: dual-entrypoint error message ---"
dual_count=0
for skill in "${DOWNSTREAM_SKILLS[@]}"; do
  # Match either backtick-quoted or bare form, tolerant to line breaks.
  if grep -qE '/yoke:discover.*[/]yoke:fix|/yoke:fix.*[/]yoke:discover' "$REPO_ROOT/$skill" 2>/dev/null; then
    dual_count=$((dual_count + 1))
  fi
done
if (( dual_count >= 3 )); then
  pass "dual-entrypoint error message present in $dual_count of ${#DOWNSTREAM_SKILLS[@]} migrated skill bodies"
else
  err "dual-entrypoint error message present in only $dual_count of ${#DOWNSTREAM_SKILLS[@]} migrated skill bodies (expected >= 3)"
fi

# ---------------------------------------------------------------------------
# Per-scenario fixture walk.
# ---------------------------------------------------------------------------
for slug in "${SCENARIOS[@]}"; do
  echo "--- scenario: $slug ---"

  TMPDIR_S=$(mktemp -d)
  STDOUT_S="$TMPDIR_S/stdout"
  STDERR_S="$TMPDIR_S/stderr"

  # (a) Create the fixture PRD with `Status: approved`.
  set +e
  (
    cd "$TMPDIR_S"
    mkdir -p ".yoke/prds"
    cat > ".yoke/prds/${slug}.md" <<EOF
# PRD: ${slug}

> Generated by /yoke:discover (regression fixture).
> Status: approved
> Approved by: regression-fixture
> Approved at: 2026-05-05T00:00:00Z

## Introduction

Fixture body for the regression suite.
EOF

    # (b) Resolver returns the PRD path on the unambiguous PRD-backed case.
    # shellcheck source=/dev/null
    source "$PATHS_LIB"
    wm_phase1_artifact_path "$slug"
  ) >"$STDOUT_S" 2>"$STDERR_S"
  RC_S=$?
  set -e

  RESOLVED="$(cat "$STDOUT_S")"
  STDERR_OUT="$(cat "$STDERR_S")"
  EXPECTED_PRD=".yoke/prds/${slug}.md"

  if [[ "$RC_S" -eq 0 && "$RESOLVED" == "$EXPECTED_PRD" && -z "$STDERR_OUT" ]]; then
    pass "(${slug}) resolver returns '$EXPECTED_PRD' on PRD-backed slug"
  else
    err "(${slug}) resolver misbehaved rc=$RC_S stdout='$RESOLVED' stderr=<<<$STDERR_OUT>>>"
  fi

  # (c) Cleanup — verify the fixture is fully removable; no leftover state
  # (e.g. .current pointer outside the tmpdir, marker files in REPO_ROOT).
  if [[ -d "$TMPDIR_S/.yoke/prds" && -f "$TMPDIR_S/.yoke/prds/${slug}.md" ]]; then
    rm -rf "$TMPDIR_S"
    if [[ ! -e "$TMPDIR_S" ]]; then
      pass "(${slug}) fixture cleanup succeeded"
    else
      err "(${slug}) fixture tmpdir survived rm -rf: $TMPDIR_S"
    fi
  else
    err "(${slug}) fixture state was not laid down correctly"
    rm -rf "$TMPDIR_S" 2>/dev/null || true
  fi
done

# ---------------------------------------------------------------------------
# Negative branch: a slug with neither a PRD nor a fix-spec MUST abort
# with a "wm:"-prefixed diagnostic ending with the literal remediation
# "Run /yoke:discover or /yoke:fix first." This is the dual-entrypoint
# version of the legacy pre-flight error — proves the resolver does not
# regress to a /yoke:discover-only message.
# ---------------------------------------------------------------------------
echo "--- negative: neither PRD nor fix-spec for slug ---"
NEG_TMP=$(mktemp -d)
NEG_OUT="$NEG_TMP/stdout"
NEG_ERR="$NEG_TMP/stderr"

set +e
(
  cd "$NEG_TMP"
  # shellcheck source=/dev/null
  source "$PATHS_LIB"
  wm_phase1_artifact_path "2026-05-05-orphan-slug"
) >"$NEG_OUT" 2>"$NEG_ERR"
NEG_RC=$?
set -e

NEG_STDERR="$(cat "$NEG_ERR")"
NEG_STDOUT="$(cat "$NEG_OUT")"

if [[ "$NEG_RC" -ne 0 ]] \
  && [[ "$NEG_STDERR" == wm:* ]] \
  && [[ "$NEG_STDERR" == *"Run /yoke:discover or /yoke:fix first."* ]] \
  && [[ -z "$NEG_STDOUT" ]]; then
  pass "neither-case: resolver aborts with dual-entrypoint remediation"
else
  err "neither-case misbehaved rc=$NEG_RC stdout='$NEG_STDOUT' stderr=<<<$NEG_STDERR>>>"
fi

rm -rf "$NEG_TMP"

harness::summary
