---
id: llm-as-judge
type: inferential
token_cost: 3000
time_cost: 60
agent: semantic-judge
---

# llm-as-judge

Standard meta-sensor — generic LLM-as-judge for arbitrary criteria
that don't fit the `code-review` lens. Spawned by `/yoke:implement`'s
per-cycle batch via `subagent_type: semantic-judge`.

Use this sensor when you need a judge that:
- Verifies a property the host CI can't check (language policy
  compliance, prose-quality, semantic equivalence after refactor,
  privacy redaction completeness, accessibility-claim verification).
- Renders a verdict over markdown / docs / specs rather than code.
- Applies a project-specific rubric not covered by `code-review`.

Per-criterion specialization happens in the AC's `### Validation`
block — the criterion's bullet for `llm-as-judge` MUST inline a
`Rubric:` and `Pass when:` clause that the dispatch path lifts into
the agent's spawn input. The bare `## Calibration` block below is a
neutral default that defers to the per-criterion rubric.

## How to run

Spawned by `/yoke:implement`. Coordinator passes:
- Sensor file path (this file).
- Criterion-specific `Rubric:` text from the AC's `### Validation`.
- Modified files / artifacts under review.

Agent reads + applies the criterion-scoped rubric and emits one
JSON verdict.

## Known issues

- Without a per-criterion rubric in `### Validation`, this sensor
  defaults to "evaluate the artifact against any explicitly stated
  property in the criterion text" — verdicts on under-specified
  criteria carry low confidence.

## Frequent errors

- ac-criterion-lacks-rubric-clause: judge falls back to literal criterion-text interpretation; surface the missing rubric in the verdict's `fix_instruction`.

## Calibration

### Prompt

You are evaluating an artifact against the criterion below. Apply
the rubric provided in the criterion's `### Validation` block.
Emit one JSON verdict matching the schema.

Criterion: {{criterion_id}} — {{criterion_text}}
Per-criterion rubric: {{rubric_from_validation_block}}
Artifact under review: {{artifact}}

### Rubric

The per-criterion rubric (lifted from the AC's `### Validation`
block) is the authoritative rubric for this verdict. The neutral
default below applies only when the AC criterion does not specify:

- pass: the artifact satisfies the property explicitly stated in the
  criterion text.
- fail: the artifact violates a property explicitly stated.
- when the criterion is under-specified: emit `confidence < 0.5` and
  cite the missing rubric in `fix_instruction`.

### Verdict schema

```json
{
  "criterion": "<criterion-id>",
  "sensor": "llm-as-judge",
  "status": "pass" | "fail",
  "location": "<file:line>" | null,
  "fix_instruction": "<text>" | null,
  "evidence": "<text>",
  "confidence": 0.0,
  "supporting_quotes": ["<quote>", "..."]
}
```
