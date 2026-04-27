#!/usr/bin/env bash
# bootstrap-creates-sprints.sh — fixture used by the
# `bootstrap-creates-sprints-dir` sensor in
# `.yoke/acceptance-contracts/2026-04-27-sprint-as-cycle.md`.
#
# Asserts that `skills/bootstrap/SKILL.md` documents the new sprints/
# archive category as the per-task working-memory layout (no `.yoke/tasks/`
# residue). The /yoke:bootstrap skill itself does not pre-create any
# archive directory — those are lazily created by /yoke:discover and
# downstream skills (/yoke:tech-spec creates .yoke/sprints/<slug>-s<NN>.md
# per the sprint-as-cycle PRD). The fixture therefore verifies the
# documentation contract:
#   * skills/bootstrap/SKILL.md mentions `sprints/` in the archive list.
#   * skills/bootstrap/SKILL.md does NOT mention `tasks/` in the archive list.
# The latter is the legacy-residue gate; the former proves the new shape
# is documented (i.e. the consumer skill is rewritten, not just stripped).

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

skill="skills/bootstrap/SKILL.md"

if [ ! -f "$skill" ]; then
  echo "FAIL: $skill not found" >&2
  exit 1
fi

# Positive assertion: sprints/ appears in the archive-category prose.
if ! grep -qE 'sprints/' "$skill"; then
  echo "FAIL: $skill does not mention sprints/ — expected per the sprint-as-cycle PRD" >&2
  exit 1
fi

# Negative assertion: legacy `tasks/` residue must be gone.
if grep -qE '`tasks/`' "$skill"; then
  echo "FAIL: $skill still mentions \`tasks/\` archive category — should be sprints/" >&2
  exit 1
fi

echo "PASS: skills/bootstrap/SKILL.md documents sprints/ archive category"
