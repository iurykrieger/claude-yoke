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
id: bedrock-canonize-roundtrip
type: computational
token_cost: 0
time_cost: 30
# command is required iff type: computational
command: <!-- TODO: fill -->
# agent is required iff type: inferential (and command MUST be absent)
# agent: <subagent-id>
---

# bedrock-canonize-roundtrip

## How to run

<!--
Describe how to invoke this sensor end-to-end:
- For `type: computational`: the exact shell invocation (mirrors the
  `command:` field, but the body explains context — what working
  directory, what env vars, expected exit codes).
- For `type: inferential`: how the subagent is spawned, what input it
  consumes, where the verdict JSON is written, how to read it.

Single section, prose-with-code-blocks acceptable. Required, must
be non-empty.
-->

## Known issues

<!--
Catalog of known caveats about THIS SENSOR (flakes, environmental
dependencies, tool gotchas). Free-form bullets. Append-only via
`/yoke:consolidate-sensors`. Required, must be non-empty.

Examples:
- Times out under 30s on cold DB; warm with `make seed-test-db`.
- Skips on macOS — uses GNU-only `find -printf`.
- False positive when the file ends without a trailing newline.
-->

## Frequent errors

<!--
Catalog of recurring pitfalls this sensor has caught in the code
under analysis. Strict bullet format: `- <pattern>: <fix>` (single
line per bullet). Required, must be non-empty. Multi-line bullets
are rejected by the lint in v0.

Examples:
- Missing trailing newline on YAML frontmatter: append `\n` before save.
- Tab indentation inside YAML block: convert to two spaces.
- Bare `git push` without upstream: use `git push -u origin <branch>`.
-->

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

<!-- Inferential only: the prompt the subagent receives. -->

### Rubric

<!-- Inferential only: the rubric the subagent applies. -->

### Verdict schema

<!--
Inferential only: the JSON envelope the subagent must return. The
parser validates the envelope; an invalid verdict equals sensor fail.

Standard envelope:
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

`confidence` is a float in `[0, 1]`. `supporting_quotes` is a list of
strings; minimum 1 entry when `status: fail`; empty list permitted
when `status: pass`.
-->
