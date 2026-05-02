---
id: code-review
type: inferential
token_cost: 4000
time_cost: 90
agent: semantic-judge
---

# code-review

Standard inferential sensor — LLM-as-judge code review of the
recent diff against project conventions. Spawned by
`/yoke:implement`'s per-cycle batch via
`subagent_type: semantic-judge`.

Inputs at spawn:

- Criterion id + text from the active Acceptance Contract.
- Generator's cycle diff (under review).
- This file's `## Calibration` block (Prompt + Rubric + Verdict
  schema), lifted verbatim by the dispatch path.
- Verdict-output path
  (`.yoke/runtime/.judge-verdicts/cycle-<N>/<criterion>--<sensor>.json`).

Per-criterion specialization happens in the AC's `### Validation`
block — different criteria can scope the rubric (security focus,
performance focus, pattern conformance focus) without authoring
per-criterion sensor files.

## How to run

Spawned by `/yoke:implement`. Coordinator passes the sensor file
path; agent reads `## Calibration` and emits one JSON verdict.

## Known issues

- Verdict drifts on model upgrade — recheck calibration after every
  coordinator-pinned-model change.
- Cold-start may emit low-confidence on first cycle; stabilizes.

## Frequent errors

- style-nitpicks-dominate-verdict: refine rubric to prioritize correctness over style.
- out-of-scope-refactor-flagged-as-fail: cite explicit scope in the criterion text so the rubric ignores out-of-scope changes.

## Calibration

### Prompt

You are reviewing a code diff against the criterion below. Apply
the rubric strictly. Emit one JSON verdict matching the schema.

Criterion: {{criterion_id}} — {{criterion_text}}
Diff under review: {{diff}}

### Rubric

- pass: the diff implements the criterion correctly, follows project
  conventions (CLAUDE.md, canonical patterns), introduces no new
  bugs detectable by reading.
- fail: any of: criterion not implemented; convention violated;
  detectable bug introduced; security/correctness regression.

Style-only issues (formatting, naming nitpicks) → pass with a note
in `evidence`. Structural issues (logic, contracts, invariants) →
fail.

### Verdict schema

```json
{
  "criterion": "<criterion-id>",
  "sensor": "code-review",
  "status": "pass" | "fail",
  "location": "<file:line>" | null,
  "fix_instruction": "<text>" | null,
  "evidence": "<text>",
  "confidence": 0.0,
  "supporting_quotes": ["<quote>", "..."]
}
```
