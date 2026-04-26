---
template: semantic-judge
version: 1.0.0
class: inferential
calibrated_against: claude-opus-4-7
calibrated_at: 2026-04-25
known_false_positives: 0
known_false_negatives: 0
criterion_scope:
  - semantic-alignment-with-tech-spec
  - error-message-voice
  - readme-vs-api-consistency
default_timeout_seconds: 120
---

# Inferential template: `semantic-judge`

> First concrete inferential-sensor template. Loaded by the
> `agents/semantic-judge.md` subagent at spawn time. Calibration metadata
> in the frontmatter is **mandatory** — without it this template cannot
> be referenced in a binding Acceptance Contract per
> `patterns/sensors.md`.

## What this template can judge

This template binds an LLM judge to a narrow set of **scope tags**
(see `criterion_scope` in the frontmatter). Use it when a deterministic
sensor cannot decide a criterion but the criterion still admits
agent-consumable evidence — e.g., does a diff match the spec's intent,
does an error message follow team voice, does the README change track
the API change.

Do **not** use this template for:
- Compliance / regulatory judgment — those are MUST policies and
  require synchronous human ratification per Model C.
- Calibration drift evaluation — that is `/yoke:drift-sense`'s job.
- Code-style judgments better expressed as a linter rule — promote
  the rule into a computational sensor instead.

## Calibration metadata (frontmatter)

| Field | Meaning |
| :--- | :--- |
| `calibrated_against` | The model id this template's prompt was tuned for. Re-tune on major model upgrades (rippability principle). |
| `calibrated_at` | ISO-8601 date of the last calibration pass. |
| `known_false_positives` | Count or rate of `pass` verdicts that turned out to be wrong, observed in working memory. |
| `known_false_negatives` | Count or rate of `fail` verdicts that turned out to be wrong. |
| `criterion_scope` | Tags identifying which kinds of Acceptance Contract criteria this template can judge. |
| `default_timeout_seconds` | Default 120s for inferential judges; per-sensor override via Acceptance Contract bullet. |

Calibration drift values (`known_false_positives`,
`known_false_negatives`) are **per-host** observations. They live in
`.yoke/sensors/<sensor-name>.md` (working memory) — not in this
template. The template ships with the initial calibration only;
observed drift is appended locally and promoted to canonical via
`/yoke:preserve` under Model C.

## Spawn-time inputs

The Validator spawns one subagent per inferential sensor and passes
exactly three inputs (no broader project context — adversarial
separation per `patterns/roles.md`):

| Input | Description |
| :--- | :--- |
| `{{criterion}}` | Verbatim Acceptance Contract criterion text the judge must evaluate. |
| `{{diff}}` | The Generator's cycle diff under review (the changes the judge is judging). |
| `{{calibration_block}}` | A YAML block containing the template's frontmatter, plus the host-specific calibration drift loaded from `.yoke/sensors/<sensor-name>.md` (when present). |

The judge **does not** receive `progress.md`, `query-trace.md`,
`contracts.md`, or any other working-memory artifact. If the criterion
references additional context, that context must be inlined into
`{{criterion}}` by the Validator at spawn time.

## Prompt skeleton

```
You are a calibrated semantic judge. Your single task is to evaluate
the diff below against the criterion. Emit one structured JSON verdict
on stdout — nothing else.

## Calibration block

{{calibration_block}}

## Criterion

{{criterion}}

## Diff under review

{{diff}}

## Verdict requirements

- Output exactly one JSON object with these keys:
  - "criterion": <verbatim criterion id from above>
  - "status": "pass" | "fail" | "skip"
  - "location": "<file:line-range>" | null  (point at the diff hunk
                that drove your judgment; null only if the criterion
                does not point to a single hunk)
  - "fix_instruction": "<the specific change the diff would need to
                       satisfy the criterion>" | null
  - "sensor": "<sensor name from the Acceptance Contract bullet>"
  - "evidence": "<a quoted excerpt from the diff or your reasoning;
                non-empty for every status, including 'pass'>"

- Back-pressure rule: pass without evidence is a sensor bug. Always
  populate "evidence", even on pass — quote the line from the diff
  that satisfies the criterion.

- If the diff does not contain enough information to judge, return
  status: "skip", evidence: "<what was missing>", and recommend in
  fix_instruction what the Validator should surface next cycle.

- Do not fabricate file paths, line numbers, or rule references.
- Do not include prose outside the JSON object.
```

## Per-host calibration drift contract

After every cycle in which this template fires, the
`agents/semantic-judge.md` subagent appends one row to
`.yoke/sensors/<sensor-name>.md` recording the verdict and any
post-hoc correction the Validator makes (e.g., when a `pass` is
contradicted by a computational sensor on the same criterion).

Drift file shape:

```yaml
template: semantic-judge
sensor: <name>
host_observations:
  - cycle: <int>
    verdict: pass | fail | skip
    overturned_by: <none | computational-sensor:<name> | human-review>
    note: "<short reason>"
```

The drift file is **working-memory** scope (task-local). It resets
with each new task's `.yoke/`. Promotion to canonical memory happens
only via `/yoke:preserve` under Model C — never automatically by
this template or its subagent.

## Anti-patterns

- Reusing this template for criteria outside `criterion_scope` —
  the calibration metadata is meaningless for those criteria.
- Emitting prose verdicts ("the diff looks good to me") — sensor
  bug per `patterns/sensors.md`.
- Calling the judge with broader context (progress.md, query-trace.md,
  the full PRD) — defeats adversarial separation.
- Persisting drift to canonical memory directly — bypasses Model C.
