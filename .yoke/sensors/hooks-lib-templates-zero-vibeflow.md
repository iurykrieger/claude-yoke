<!--
templates/sensor.md — per-sensor working-memory artifact template.

The host project's `.yoke/sensors/<sensor-id>.md` is the source of truth
for a single sensor's command, class, tier, criterion mapping, accumulated
caveats and run history. Acceptance Contracts reference sensors by `id`;
they no longer inline the command, class or tier.

Created and refreshed by `/yoke:ack-sensors --mode upsert` (Part 2 of
sensor-cost-tiering — see .vibeflow/prds/sensor-cost-tiering.md). Read
by `hooks/verify-acceptance.sh` (Part 3) and by `agents/validator.md`
(Part 4). Run-history entries are appended by `skills/implement/SKILL.md`
(Part 5).

Tier default is class-based: computational sensors default to `cheap`;
inferential sensors default to `expensive`. The author may override either
way via the `tier:` field below — explicit value always wins.

Heavy computational sensors (Playwright, browser automation) MUST set
`tier: expensive` explicitly — the class-based default is a starting
point, not a substitute for author judgment.
-->
---
id: hooks-lib-templates-zero-vibeflow
command: |
  test "$(grep -rcF '.vibeflow/' hooks/ lib/ templates/ 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')" = "0"
class: computational
tier: cheap
applies_to: [2026-04-27-yoke-doctrine-canonization-s04-t03]
runs: []
---

# hooks-lib-templates-zero-vibeflow

## Caveats

<!--
Known flakes, environmental dependencies, calibration notes, and other
context the Validator should weigh when scheduling this sensor. Free-form
markdown.

Examples:
- "Times out under 30 s when test DB is cold; warm with `make seed-test-db`."
- "Skips on macOS — uses GNU-only `find -printf`."
- "Calibrated against claude-opus-4-7 on 2026-04-22; recheck on model upgrade."
-->

## Calibration notes

<!--
Inferential sensors only. Document the prompt, rubric, and known
false-positive / false-negative rates. Computational sensors leave this
section empty.
-->
