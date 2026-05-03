#!/usr/bin/env bash
# orphan-acceptance-contract-refs.test.sh
#
# Smoke sensor for the v4.0.0 acceptance-criteria cutover. Greps active
# code paths for any residual `acceptance-contract(s)?` reference and
# exits non-zero if any unaccounted match exists.
#
# Allowlist (intentional historical references):
#   - docs/migration-v3-to-v4.md (the migration doc itself documents
#     the rename and naturally contains both the old and new names).
#   - The "Migration history" block of the project CLAUDE.md, delimited
#     by `^## Migration history$` and the next `^## ` heading. The
#     historical entries reference the legacy directory because the
#     historical Acceptance Contract files literally live there per
#     the no-historical-migration policy.
#   - `> **Lineage.**` quote blocks inside skill bodies — these
#     intentionally cite the Vibeflow / Bedrock upstream lineage and
#     reference the legacy "Acceptance Contract" name.
#   - Comments in sensor scripts that document the Source PRD /
#     Acceptance Contract path of historical files — those file paths
#     are real on-disk artifacts under `.yoke/acceptance-contracts/`.
#   - The `tests/acceptance/<contract-slug>/` test-directory
#     convention term `contract-slug` (a parameter name, not a path).

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Active code paths to scan. Intentionally excludes:
#   - .yoke/ (working memory; historical files frozen per policy)
#   - .git/ (vcs state)
#   - tests/smoke/orphan-acceptance-contract-refs.test.sh (this script;
#     it documents the legacy name in its own comments)
SCAN_PATHS=(
  skills/
  agents/
  hooks/
  lib/
  templates/
  CLAUDE.md
  .claude-plugin/
  docs/
)

# Collect every match.
matches="$(grep -RInE 'acceptance-contract(s)?' "${SCAN_PATHS[@]}" 2>/dev/null || true)"

# Apply allowlist filters.
#
# Allowlist rationale (each filter line is annotated with WHY):
#   1. Migration docs intentionally document both legacy and new names.
#   2. The `> **Lineage.**` quote blocks cite Vibeflow / Bedrock upstream
#      lineage and reference the legacy "Acceptance Contract" name.
#   3. The `<contract-slug>` parameter name in the
#      `tests/acceptance/<contract-slug>/` directory convention; renaming
#      the test-dir convention is out of scope for v4.0.0.
#   4. The phrase "acceptance-contract-anchored tests" — same convention.
#   5. Sensor scripts that walk historical files reference
#      `.yoke/acceptance-contracts/` because those files literally live
#      there (no-historical-migration policy); same for `Source PRD:`
#      breadcrumbs.
#   6. The `skills/acceptance-criteria/SKILL.md` migration narrative
#      paragraphs (e.g., "v4.0.0 cutover") that cite the legacy name.
#   7. The `concepts/yoke-pattern-acceptance-contract` canonical-memory
#      entity ID — the entity is superseded by v4.0.0's pattern but the
#      ID survives as a citation target for traceability.
#   8. Sensor `migration-audit.sh` and `yoke-doctrine-round-trip.sh`
#      directory references — these sensors specifically audit historical
#      contracts and must reference the legacy directory.
#   9. Decision-token strings in `lib/ralph-loop/escalate.sh`
#      (`acceptance-contract-violation`, `reformulate-acceptance-contract`)
#      — these are runtime category strings emitted in escalation packets;
#      renaming them is a separate v4.x cleanup follow-up.
#  10. The legacy `WM_ARCHIVE_CATEGORIES` entry retained for the
#      historical directory (per the no-historical-migration policy).
filtered="$(printf '%s\n' "$matches" \
  | grep -v '^docs/migration-v3-to-v4\.md:' \
  | grep -v '^docs/migration-v[12]-to-v[23]\.md:' \
  | grep -v '> \*\*Lineage\.' \
  | grep -v 'contract-slug' \
  | grep -v 'acceptance-contract-anchored' \
  | grep -v 'Source PRD:' \
  | grep -v 'Source: \.yoke/acceptance-contracts/' \
  | grep -v ' Acceptance Contract:' \
  | grep -v '\.yoke/acceptance-contracts/2026-' \
  | grep -v 'concepts/yoke-pattern-acceptance-contract' \
  | grep -v 'pattern-acceptance-contract' \
  | grep -v 'lib/sensors/migration-audit\.sh:' \
  | grep -v 'lib/sensors/yoke-doctrine-round-trip\.sh:' \
  | grep -v 'lib/sensors/ack-sensors\.sh:' \
  | grep -v 'lib/sensors/check-vibeflow-refs-scope\.sh:' \
  | grep -v 'lib/working-memory/paths\.sh:.*acceptance-contracts' \
  | grep -v 'lib/ralph-loop/escalate\.sh:.*acceptance-contract' \
  | grep -v 'skills/acceptance-criteria/SKILL\.md:.*acceptance-contracts' \
  | grep -v 'skills/acceptance-criteria/SKILL\.md:.*yoke-pattern-acceptance-contract' \
  | grep -v 'templates/project-claude-md\.md:.*replacing the v3\.x' \
  | grep -v 'docs/lineage\.md:.*skills/acceptance-contract/SKILL\.md' \
  || true)"

# CLAUDE.md "Where things live" entry that documents the cutover
# rename (line 70-ish): "v4.0.0 cutover from the legacy
# .yoke/acceptance-contracts/ directory" — intentional and load-bearing
# for the migration narrative.
filtered="$(printf '%s\n' "$filtered" \
  | grep -v 'CLAUDE\.md:.*v4\.0\.0 cutover from the legacy' \
  || true)"

# CLAUDE.md "Migration history" block — strip every line whose path
# is CLAUDE.md AND whose line-number is inside the block. This is an
# awk pass against CLAUDE.md to compute the block's line range.
if [ -f CLAUDE.md ]; then
  block_range="$(awk '
    /^## Migration history[[:space:]]*$/ { start = NR; next }
    start > 0 && /^## / { end = NR - 1; print start, end; exit }
    END { if (start > 0 && end == 0) print start, NR }
  ' CLAUDE.md)"
  if [ -n "$block_range" ]; then
    block_start="$(echo "$block_range" | awk '{print $1}')"
    block_end="$(echo "$block_range" | awk '{print $2}')"
    filtered="$(printf '%s\n' "$filtered" \
      | awk -v start="$block_start" -v end="$block_end" '
          /^CLAUDE\.md:/ {
            split($0, a, ":")
            ln = a[2] + 0
            if (ln >= start && ln <= end) next
          }
          { print }
        ')"
  fi
fi

# Empty matches → exit 0.
filtered="$(printf '%s' "$filtered" | grep -v '^[[:space:]]*$' || true)"

if [ -z "$filtered" ]; then
  echo "wm: orphan-acceptance-contract-refs: 0 unaccounted matches"
  exit 0
fi

echo "wm: orphan-acceptance-contract-refs: unaccounted references found:" >&2
printf '%s\n' "$filtered" >&2
exit 1
