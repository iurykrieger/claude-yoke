#!/bin/bash
# Sensor: zero references to the legacy doctrine directory in framework
# surface, AND zero re-introduction of v1.x canonical-memory artifacts
# extracted to claude-bedrock at v2.0.0.
#
# Two invariants pinned by this sensor:
#   1. (legacy-doctrine) — no `.vi`+`beflow/` token under
#      skills/ agents/ hooks/ lib/ templates/. Tripwire from Sprint 4
#      of the 2026-04-27 doctrine-canonization PRD.
#   2. (v2.0.0 migration) — top-level `entities/` and
#      `templates/canonical/` directories MUST NOT exist in
#      claude-yoke. They moved to the claude-bedrock peer plugin per
#      PRD `2026-04-30-pluggable-canonical-memory.md`, Sprint 03 task
#      s03-t03. Re-introduction of either is treated as a violation.
#
# Exits 0 if both invariants hold; non-zero with diagnostic stderr
# otherwise.
#
# Implementation note: the legacy-doctrine search needle is constructed
# at runtime from two halves so this script can be migrated, audited,
# and version-controlled without tripping its own check.
# (Self-reference paradox: a sensor that searches for string X must
# mention string X to do its job. Constructing the needle from parts
# breaks the paradox.)
#
# Source: .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md
# Scenario 14 / FR-1 / FR-4 (legacy-doctrine), and
# .yoke/acceptance-contracts/2026-04-30-pluggable-canonical-memory.md
# Scenario 13 / FR-8 (v2.0.0 migration).
set -euo pipefail
needle=".vi""beflow/"
matches="$(grep -rnF "$needle" skills/ agents/ hooks/ lib/ templates/ 2>/dev/null \
  | grep -vF "$(basename "$0")" \
  | grep -vF "no-vibeflow-refs.test.sh" \
  || true)"
if [[ -n "$matches" ]]; then
  echo "$matches" >&2
  echo "sensor: no-vibeflow-refs found $(echo "$matches" | wc -l) match(es)" >&2
  exit 1
fi

# v2.0.0 migration invariant: claude-yoke/entities/ and
# claude-yoke/templates/canonical/ must not reappear. Both moved to
# the claude-bedrock peer plugin in s03-t03. Re-introduction is a
# regression of the extraction sprint.
if [[ -d entities ]]; then
  echo "entities/: directory must not exist in claude-yoke (moved to claude-bedrock at v2.0.0)" >&2
  echo "sensor: no-vibeflow-refs migration-pin violation — entities/ reintroduced" >&2
  exit 1
fi
if [[ -d templates/canonical ]]; then
  echo "templates/canonical/: directory must not exist in claude-yoke (moved to claude-bedrock at v2.0.0)" >&2
  echo "sensor: no-vibeflow-refs migration-pin violation — templates/canonical/ reintroduced" >&2
  exit 1
fi

exit 0
