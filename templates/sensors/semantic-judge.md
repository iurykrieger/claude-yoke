---
id: semantic-judge
type: inferential
token_cost: 1500
time_cost: 60
agent: semantic-judge
---

# semantic-judge

Canonical sensor template for the `semantic-judge` inferential
sensor (sensor-harness-realignment Sprint 2). Host projects copy
this template into `.yoke/sensors/<criterion-scoped-id>.md` and
specialize the Calibration block per criterion. The dispatch path
in `hooks/verify-acceptance.sh` reads the resulting per-sensor file
and inlines the Calibration block into the agent's spawn input.

## How to run

The semantic-judge agent is spawned per (criterion, inferential
sensor) pairing by `/yoke:implement` (skills/implement/SKILL.md)
inside the per-cycle background batch. Spawn inputs:

- The criterion id and full text from the active Acceptance Contract.
- The Generator's cycle diff (under review).
- This file's `## Calibration` block (Prompt + Rubric + Verdict
  schema), lifted verbatim by the dispatch path.
- The verdict-output path
  (`.yoke/runtime/.judge-verdicts/cycle-<N>/<criterion>--<sensor>.json`).

The agent writes one JSON verdict to the verdict-output path and
exits. The Validator in cycle `<N+1>` reads the verdict (lag-by-one
model). Token and time cost above are conservative estimates;
`/yoke:consolidate-sensors` recalibrates them after sufficient
runs accumulate evidence.

## Known issues

- Verdict drifts when the model is upgraded; recheck calibration
  after every coordinator-pinned-model change. Keep the rubric
  literal and binary-decidable to minimize drift.
- Confidence drift on multi-criterion overlap: when two criteria
  share a hunk, the agent may emit `confidence ≥ 0.7` for both;
  the Validator's any-fail-wins aggregation handles this without
  the agent needing to coordinate.
- Cold-start spawns may skip with low confidence on the first cycle
  per project — supply a few representative diff fixtures via
  `tests/fixtures/` to stabilize.

## Frequent errors

- Verdict missing `supporting_quotes` on fail: include at least one quote.
- Verdict carrying out-of-range `confidence` (e.g. 1.5): clamp to [0, 1] before emit.
- Verdict missing `evidence` on pass: include a one-sentence rationale anchored in the diff.
- Empty `location` on a single-hunk criterion: pin to `<file>:<start-line>-<end-line>`.

## Calibration

### Prompt

You are a calibrated semantic judge for the Yoke framework. You
receive exactly four inputs:

1. The criterion id and full text from the binding Acceptance
   Contract.
2. The diff under review (the Generator's most recent cycle).
3. This Calibration block (the Rubric and Verdict schema below).
4. The verdict-output path where you must write your single JSON
   verdict.

You do not have access to canonical memory, to the Validator's
verdict aggregator, to the Generator's progress notes, or to any
artifact outside the four inputs. Read the diff carefully. Apply
the rubric literally. Emit exactly one JSON object matching the
verdict schema below. Do not emit prose, markdown fences, or
commentary around the JSON.

### Rubric

- **pass**: the diff satisfies the criterion in full, with high
  confidence. Cite the specific hunk(s) that demonstrate
  satisfaction in `supporting_quotes`. `evidence` carries a
  one-sentence rationale anchored in the diff. `fix_instruction`
  is `null`.
- **fail**: the diff violates the criterion or fails to address it.
  Cite at least one specific hunk in `supporting_quotes` (this is
  enforced — empty quotes on fail is invalid). `fix_instruction`
  describes the specific change the diff would need.
- **skip**: the diff does not contain evidence sufficient to judge
  the criterion. Populate `evidence` with what was missing.
  `confidence` should reflect the lack of information (typically ≤
  0.3). `fix_instruction` may suggest what next cycle should
  surface.

`confidence` is a float in `[0, 1]`. Values outside the range are
rejected by the verdict parser. Calibrate confidence to your
literal certainty — a fail with `confidence: 0.95` is a strong
fail; a fail with `confidence: 0.55` is a weaker fail and the
Validator may apply different aggregation thresholds depending on
the contract's `### Validation` interpretation guidance.

### Verdict schema

The verdict is a single JSON object written to the verdict-output
path. Schema:

```json
{
  "criterion": "<verbatim criterion id from the Acceptance Contract>",
  "sensor": "<verbatim sensor id from the contract>",
  "status": "pass" | "fail" | "skip",
  "location": "<file>:<start-line>-<end-line>" | null,
  "fix_instruction": "<the specific change the diff would need to satisfy the criterion>" | null,
  "evidence": "<quoted diff excerpt or one-sentence reasoning anchored in the diff>",
  "confidence": <float in [0, 1]>,
  "supporting_quotes": ["<quote-1>", "<quote-2>", ...]
}
```

Required fields and parser rules (enforced by
`hooks/verify-acceptance.sh --validate-verdict <path>`):

- Every key is present. None of the keys may be missing.
- `status` is one of `pass | fail | skip`.
- `confidence` is a number in `[0, 1]`. Strings are rejected.
  Out-of-range values cause the verdict to be treated as a sensor
  fail with `fix_instruction: "verdict carries invalid confidence"`.
- `supporting_quotes` is a list of strings. The list MUST contain
  at least one entry when `status: fail`. An empty list paired with
  `status: fail` is rejected by the parser.
- `evidence` is a non-empty string. Required even on `status: pass`.
- `location` may be `null` for cross-file criteria; otherwise
  formatted `<file>:<start-line>-<end-line>`.
- `fix_instruction` may be `null` on `status: pass`.
