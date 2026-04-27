#!/bin/bash
# Sensor: zero-residue invariant for the sprint-as-cycle migration.
#
# Pins two post-migration invariants from the sprint-as-cycle PRD:
#   1. No `.yoke/specs/<slug>-part-N.md` files remain (legacy multi-part
#      spec convention from the pre-2026-04-25 tech-spec-task-split
#      rollout) — every legacy part must be renamed to
#      `.yoke/sprints/<slug>-s<NN>.md` via git mv during sprint 2.
#   2. No `.yoke/tasks/<slug>-s<NN>-t<MM>.md` files remain — every
#      legacy task file must be concatenated into the matching
#      `.yoke/sprints/<slug>-s<NN>.md` runtime bundle during sprints
#      2 and 4 of the PRD.
#
# Output: one structured JSON object per violation, newline-delimited
# on stdout. Schema (per concepts/yoke-pattern-sensors "Structured
# sensor output" rule):
#   {"criterion": "<id>", "status": "fail",
#    "location": "<path>", "fix_instruction": "<actionable text>",
#    "sensor": "legacy-parts-zero-residual", "evidence": "<phrase>"}
#
# Exit codes:
#   0 — zero violations; clean tree
#   1 — one or more violations; each emitted as a JSON object on stdout
#
# No arguments. Operates on the working tree from the repo root.
#
# Source: .yoke/acceptance-contracts/2026-04-27-sprint-as-cycle.md
# Scenario 4 / FR-1. Pin from sprint 1 task t04.
set -euo pipefail

SENSOR_ID="legacy-parts-zero-residual"
CRITERION_ID="legacy-parts-zero-residual"

violations=0

# Emit one JSON violation object to stdout. JSON-escapes the path,
# fix_instruction, and evidence values so embedded quotes/backslashes
# in filenames don't break the structured-output contract.
emit_violation() {
    local location="$1"
    local fix="$2"
    local evidence="$3"
    # Minimal JSON string escape — backslash and double-quote.
    local esc_location esc_fix esc_evidence
    esc_location="${location//\\/\\\\}"; esc_location="${esc_location//\"/\\\"}"
    esc_fix="${fix//\\/\\\\}";          esc_fix="${esc_fix//\"/\\\"}"
    esc_evidence="${evidence//\\/\\\\}"; esc_evidence="${esc_evidence//\"/\\\"}"
    printf '{"criterion":"%s","status":"fail","location":"%s","fix_instruction":"%s","sensor":"%s","evidence":"%s"}\n' \
        "$CRITERION_ID" \
        "$esc_location" \
        "$esc_fix" \
        "$SENSOR_ID" \
        "$esc_evidence"
}

# 1. Legacy `<slug>-part-N.md` files under .yoke/specs/.
if [[ -d ".yoke/specs" ]]; then
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        emit_violation \
            "$f" \
            "rename via git mv to .yoke/sprints/<slug>-s<NN>.md per the sprint-as-cycle PRD migration script" \
            "legacy -part-N spec file present"
        violations=$((violations + 1))
    done < <(find .yoke/specs -maxdepth 1 -type f -name '*-part-[0-9]*.md' 2>/dev/null | sort)
fi

# 2. Legacy `<slug>-s<NN>-t<MM>.md` task files under .yoke/tasks/.
if [[ -d ".yoke/tasks" ]]; then
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        emit_violation \
            "$f" \
            "concatenate into .yoke/sprints/<slug>-s<NN>.md per migration" \
            "legacy -s<NN>-t<MM> task file present"
        violations=$((violations + 1))
    done < <(find .yoke/tasks -maxdepth 1 -type f -name '*-s[0-9]*-t[0-9]*.md' 2>/dev/null | sort)
fi

if [[ "$violations" -gt 0 ]]; then
    exit 1
fi

exit 0
