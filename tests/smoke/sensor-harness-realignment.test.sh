#!/usr/bin/env bash
# tests/smoke/sensor-harness-realignment.test.sh
#
# CI-gate smoke for the sensor-harness-realignment PRD's three
# permanent invariants. Runs the three permanent tests below under
# the framework's `set -euo pipefail` watchdog convention; any
# regression in dispatch-by-type, body-lint, or consolidation-stage
# fails the gate before merge.
#
# Three invariants gated:
#   1. dispatch-by-type — type-aware dispatch in
#      hooks/verify-acceptance.sh: computational via shell,
#      inferential via Task spawn with verdict JSON persisted.
#   2. body-lint        — strict body-shape contract enforced by
#      lib/sensors/ack-sensors.sh --mode readiness against ≥11
#      fixtures.
#   3. consolidation-stage — append-only-with-citation +
#      5%-threshold cost recalibration + idempotent reentry of
#      the /yoke:consolidate-sensors skill.
#
# Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md
# (Sprint 3, t06).
set -euo pipefail

# Watchdog convention (CLAUDE.md testing section): pre-Sprint-6 smoke
# tests must guard against ralph-loop iterations or LLM-driven steps
# without hard bounds. None of the three concept tests below invokes
# an agent, but the watchdog is the framework convention — keep it.
sleep 600 && kill -TERM $$ &
WATCHDOG=$!
trap 'kill "$WATCHDOG" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "[smoke] sensor-harness-realignment — three permanent tests"

echo "[smoke] step 1/3: dispatch-by-type"
bash tests/sensors/dispatch-by-type.test.sh

echo "[smoke] step 2/3: body-lint"
bash tests/sensors/body-lint.test.sh

echo "[smoke] step 3/3: consolidation-stage"
bash tests/sensors/consolidation-stage.test.sh

echo "[smoke] all sensor tests passed"
exit 0
