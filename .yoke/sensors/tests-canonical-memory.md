<!--
templates/sensor.md — per-sensor working-memory artifact template.

The host project's `.yoke/sensors/<sensor-id>.md` is the canonical
knowledge base for a single sensor. Sensors are project-level,
durable harness capabilities, not per-task artifacts; the same sensor
file is referenced by any number of Acceptance Contracts and criteria
across the project's lifetime.

The body is a curated knowledge base, NOT an execution log. There is
no `runs:` array, no `recent_runs:`, no timestamps. What lives in the
body is what humans + the `/yoke:consolidate-sensors` skill have
learned about the sensor itself: how to run it, known caveats, the
catalog of frequent errors it has caught in the code under analysis,
and (for inferential sensors) the calibration prompt + rubric +
verdict schema.

Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md.

Schema rules (enforced by `lib/sensors/ack-sensors.sh --mode readiness`):

  - `type:` is the hard discriminator. `computational` means
    deterministic shell-based feedback (linters, formatters, unit
    tests, schema validators). `inferential` means non-deterministic
    judge-based feedback (LLM-as-judge, agent review, semantic
    analysis). The dispatch path differs: computational runs through
    `command:`; inferential spawns a subagent named by `agent:`.

  - `token_cost:` (int, ≥ 0) and `time_cost:` (int seconds, ≥ 1) are
    primary cost channels. Computational sensors typically declare
    `token_cost: 0`; inferential sensors declare an estimate that the
    consolidation step recalibrates from observed runtime.

  - `command:` is required iff `type: computational`; `agent:` is
    required iff `type: inferential`. The two are mutually exclusive
    — exactly one is populated per sensor file.

  - Body sections are mandatory and lint-enforced:
      `## How to run`         (any type, non-empty)
      `## Known issues`       (any type, non-empty)
      `## Frequent errors`    (any type, non-empty; bullets `- <pattern>: <fix>`)
      `## Calibration`        (only `type: inferential`; with sub-sections
                              `### Prompt`, `### Rubric`, `### Verdict schema`)

  - Legacy fields `class:`, `tier:`, `applies_to:`, `runs:` are
    REJECTED by the parser. A sensor file carrying any of them fails
    readiness immediately.
-->
---
id: tests-canonical-memory
type: computational
token_cost: 0
time_cost: 30
# command is required iff type: computational
command: set -e; for t in $(find tests/canonical-memory -maxdepth 2 -name '*.test.sh' | LC_ALL=C sort); do bash "$t" || exit 1; done
# agent is required iff type: inferential (and command MUST be absent)
# agent: <subagent-id>
---

# tests-canonical-memory

## How to run

Run via the value of the `command:` field above. Computational
sensors execute the literal shell command; inferential sensors are
spawned by `/yoke:implement` via `subagent_type: $agent`, which reads
the `## Calibration` block below for prompt + rubric + verdict
schema.

## Known issues

- (None recorded yet — populate via `/yoke:consolidate-sensors`
  after the loop accumulates run evidence.)

## Frequent errors

- placeholder: replace this bullet with project-specific patterns once `/yoke:consolidate-sensors` distills runtime evidence.

## Calibration

<!--
Required ONLY for `type: inferential`. Computational sensors leave
this section absent (warning emitted by lint if present, not fail).

Three mandatory sub-sections, each non-empty:
  ### Prompt          — the exact prompt the judge subagent receives.
  ### Rubric          — the criteria the subagent applies for pass/fail.
  ### Verdict schema  — the JSON envelope the subagent must return.
-->

### Prompt

Inferential only: replace this paragraph with the literal prompt the
subagent receives at spawn time. The dispatch path lifts this
verbatim into the agent's input.

### Rubric

Inferential only: replace this paragraph with the binary pass/fail
rubric the subagent applies. Keep it literal and binary-decidable to
minimize verdict drift across model upgrades.

### Verdict schema

```json
{
  "criterion": "<criterion-id>",
  "sensor": "<sensor-id>",
  "status": "pass" | "fail",
  "location": "<file:line>" | null,
  "fix_instruction": "<text>" | null,
  "evidence": "<text>",
  "confidence": 0.0,
  "supporting_quotes": ["<quote>", "..."]
}
```

`confidence` is a float in `[0, 1]`. `supporting_quotes` is a list
of strings; minimum 1 entry when `status: fail`; empty list permitted
when `status: pass`.
