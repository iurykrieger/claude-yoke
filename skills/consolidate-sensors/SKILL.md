---
name: consolidate-sensors
description: >
  Distills the active task's runtime evidence (verdicts under
  `.yoke/runtime/.judge-verdicts/`, durations under
  `.yoke/runtime/progress.md`) back into the durable
  per-sensor files at `.yoke/sensors/<id>.md`. Append-only on the
  body (`## Known issues`, `## Frequent errors`, and for inferential
  sensors `## Calibration`); each appended bullet carries a
  `(cycle N, fix-instruction X)` citation that doubles as the
  idempotence key. Frontmatter `token_cost` and `time_cost` are
  recalibrated only when observed-mean delta exceeds 5%. Reads
  `.yoke/config.yaml` for `sensor_consolidation: review | auto |
  skip` (default `review`); `skip` is a silent no-op. No arguments.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /yoke:consolidate-sensors — distill runtime evidence into sensor files

The single skill that closes the durability gap on sensor learning.
Without it, every `/yoke:implement` produces dozens of fix
instructions, calibration drifts, and runtime durations that
evaporate at loop exit. This skill reads the runtime artifacts the
loop wrote, distills the evidence per sensor (LLM-driven, not
regex), and persists the distillation back into the per-sensor
files: append-only body bullets with mandatory citations, plus
frontmatter cost recalibration when the observed mean has drifted.

Source PRD: `.yoke/prds/2026-04-30-sensor-harness-realignment.md`
(Sprint 2, task t05).

## Pre-flight

1. Source `lib/working-memory/paths.sh`. The skill resolves every
   path through the `wm_*` helpers — never hardcoded.
2. Read `.yoke/runtime/.current` to resolve the active task slug. If
   the file is missing, abort with a one-line message instructing
   the user to run `/yoke:implement` first; exit 0 (this skill is
   non-blocking — see `skills/implement/SKILL.md` teardown
   integration).
3. Verify `.yoke/runtime/.judge-verdicts/` exists. If missing or
   empty, the loop hasn't accumulated evidence; print a one-line
   summary `0 sensors updated, 0 bullets added, 0 cost values
   recalibrated, 0 skipped due to no delta` and exit 0.
4. Read `.yoke/config.yaml` for the `sensor_consolidation:` key.
   Default is `review`. Behaviour matrix:
   - `skip` — silent no-op; print the zero-summary line and exit 0.
   - `auto` — apply every distillation and recalibration without
     prompting.
   - `review` — render the cumulative diff (body appends + cost
     deltas) and prompt the user with four options:
     `accept all` / `accept partial` / `skip` / `cancel`.

## Process

### 1. Evidence collection (deterministic)

Walk `.yoke/runtime/.judge-verdicts/cycle-*/` in numerical order.
For each cycle directory, parse every JSON verdict file and emit a
record:

```
{
  "sensor": "<sensor-id>",
  "criterion": "<criterion-id>",
  "cycle": <N>,
  "status": "pass" | "fail" | "skip",
  "fix_instruction": "<text or null>",
  "confidence": <float, inferential only>,
  "evidence": "<text>"
}
```

Then read `.yoke/runtime/progress.md` and pull every
`Cycle <N>` block's `files_touched`, `citing_criterion` (or
`citing_criteria`), and any per-sensor duration entries. Group all
records by `sensor`.

### 2. Distillation (agentic node — exactly one)

For each sensor with at least one fail or skip verdict in the
collected evidence, spawn a Task call with the sensor file's
current content + the evidence list, instructing production of:

- Candidate bullets for `## Known issues` — caveats observed about
  the sensor itself (flakes, environmental gotchas).
- Candidate bullets for `## Frequent errors` — recurring patterns
  the sensor caught in the code under analysis (bullet shape:
  `- <pattern>: <fix>`).
- (Inferential only) Candidate refinements to `## Calibration`'s
  Rubric or Verdict schema sub-sections — only when evidence shows
  the rubric is producing low-confidence verdicts on calibrated
  examples.

Every candidate bullet MUST include a citation in the form
`(cycle N, fix-instruction X)` where `X` is a one-phrase summary of
the underlying fix-instruction. The citation doubles as the
idempotence key — re-running the skill against the same evidence
must produce byte-identical files because the citation grep below
short-circuits any duplicate.

This is the **only** agentic node in the skill. Everything before
(evidence collection) and after (idempotency check, file writes,
cost recalibration) is deterministic.

### 3. Idempotency check (deterministic)

Before inserting any candidate bullet, grep the target sensor file
for the literal citation substring `(cycle N, fix-instruction X)`.
If the citation already exists anywhere in the file body, drop the
candidate bullet — it has been distilled in a prior run. Repeated
invocations with unchanged evidence are byte-identical no-ops.

### 4. Cost recalibration (deterministic)

For each sensor with at least 3 observed run durations in the
collected evidence:

- Compute the mean of `time_cost` (per-cycle observed seconds).
- Compute the mean of `token_cost` (inferential only — read from
  the verdict's metadata if present, else skip).
- Read the sensor file's frontmatter declared values.
- If `|observed_mean - declared| / max(declared, 1) > 0.05`, mark
  the field for update. Otherwise leave the frontmatter untouched.

Cost updates are applied via `Edit` on the frontmatter line. The
5% threshold avoids trivial oscillation — a sensor that drifted
from 30s to 31s does NOT trigger a rewrite; one that drifted from
30s to 60s does.

### 5. Diff rendering and prompt (review mode only)

When `sensor_consolidation: review`, render the cumulative diff:

```
sensors to update: <N>
  - <sensor-id>: +<M> bullets, [cost: token_cost <old>→<new>, time_cost <old>→<new>]
  - ...
```

Then prompt the user with the canonical four-option menu:

1. **accept all** — apply every change.
2. **accept partial** — interactive per-sensor accept/reject.
3. **skip** — apply nothing this run; the evidence remains in
   `.yoke/runtime/` for the next invocation.
4. **cancel** — abort with no side effects.

In `auto` mode the prompt is bypassed and every change is applied.
In `skip` mode the skill exits at pre-flight without entering the
distillation node.

### 6. Apply changes (deterministic, atomic per sensor)

For each sensor approved for update:

- Append every approved bullet to its target body section. Append
  position: at the end of the section, before the next `## ` /
  `### ` header or EOF.
- Apply approved frontmatter cost deltas via `Edit` on the
  frontmatter line.
- Both writes go through `Edit` so an atomic-per-file outcome is
  guaranteed: failure on one sensor file leaves the others written
  and the run reports non-zero exit.

### 7. Final summary (stdout, single line)

```
<N> sensors updated, <M> bullets added, <K> cost values recalibrated, <S> skipped due to no delta
```

The summary line is the only stdout the skill emits in `auto` and
`skip` modes; in `review` mode the diff render and prompt are
emitted before the summary line.

## Output contract

- `auto` / `skip` modes: single summary line on stdout; no other
  output. Exit 0 on success.
- `review` mode: diff render + four-option prompt + summary line.
  Exit 0 on accept (full or partial) and on cancel; exit 0 also on
  skip (silent no-op); exit non-zero only on tool failure.
- Non-blocking by design — the calling skill (`/yoke:implement`'s
  teardown) does not roll back on a non-zero exit; it logs and
  proceeds.

## Anti-patterns

- Do NOT modify body sections outside the three permitted targets
  (`## Known issues`, `## Frequent errors`, `## Calibration` sub-
  sections for inferential sensors). Other sections are
  human-curated and out of scope.
- Do NOT delete bullets. Append-only is a hard invariant of this
  skill — the citation idempotence key relies on append-only to
  remain byte-stable across runs.
- Do NOT skip the citation. A bullet without `(cycle N,
  fix-instruction X)` cannot be detected by the idempotency check
  and will accumulate duplicates on re-runs.
- Do NOT recalibrate frontmatter when fewer than 3 runs are
  observed. The 3-runs minimum is the minimum statistic for "this
  is real, not noise".
- Do NOT prompt in `auto` mode. The `auto` mode exists precisely
  to bypass the human gate — prompting defeats the purpose.
- Do NOT write canonical memory. Promotion of consolidated
  insights to canonical memory happens via `/yoke:preserve` under
  Model C, not from this skill.

## See also

- `agents/generator.md` — produces the `progress.md` durations the
  skill consumes.
- `agents/validator.md` — emits the verdicts in
  `.yoke/runtime/.judge-verdicts/` the skill consumes.
- `templates/sensor.md` — defines the body section shape this
  skill appends to.
- `skills/implement/SKILL.md` — teardown integration point
  (sensor-harness-realignment Sprint 2 task t06).
