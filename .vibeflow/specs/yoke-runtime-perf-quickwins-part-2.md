# Spec: Yoke Runtime Perf Quick Wins — Part 2: Generator Persona — Plan-First + Batched Coupled Criteria

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/yoke-runtime-perf-quickwins.md`.

## Objective

Strengthen the Generator's engineer persona so each cycle starts with an
explicit plan (read all failing criteria → group coupled ones → name
files+intent in `progress.md`) and may **batch coupled criteria within a
single cycle** when planning shows shared change surface — instead of
patching one criterion per cycle and waiting for the next sensor pass.

## Context

`agents/generator.md:26-32` describes the Generator persona as "Engineer
focused on shipping. Strong instinct for mapping use cases into concrete
file changes. Keeps state across cycles in `.yoke/runtime/progress.md`."
That intent is correct but under-instructed: at runtime, the Generator
behaves as a one-criterion-at-a-time patcher. When a single bug touches
three criteria across the same file, three cycles fire — each paying the
full ralph-loop tax — instead of one cycle's worth of coordinated work.

The fix is purely behavioral and schema-shaped: sharpen the persona, add
a `plan:` block to `templates/progress.md` so the planning artifact is
deterministic and reviewable, and license batching of coupled criteria
explicitly. No agent authority changes; no new file ownership; no
manifesto invariant added.

The "coupling" heuristic is conservative: criteria are coupled when the
Tech Spec's task assigns them to overlapping file sets (or when the
sensors' violation locations from the cycle-N-1 snapshot reveal
overlapping file paths). When in doubt, the Generator does not batch.
This keeps Validator's per-criterion structured verdicts intact.

## Definition of Done

1. **Plan-first behavior is mandated in `agents/generator.md`.**
   The "Behaviors → Always" section explicitly requires, at the start
   of every cycle: (a) read all currently-failing criteria from the
   latest `cycle-<N-1>.yaml` snapshot, (b) group coupled criteria
   (heuristic: overlapping file sets in the Tech Spec task or
   overlapping sensor violation locations), (c) name files + intended
   change in the `plan:` block of `progress.md`, (d) edit only after
   the plan is written.
2. **Batched coupled criteria are licensed.**
   The same section permits the Generator to address multiple coupled
   criteria within a single cycle when the planning step shows shared
   change surface; documents the coupling heuristic; documents the
   non-batching default ("when criteria don't share files, work one
   per cycle"). The Acceptance Contract still binds — a failed
   criterion in a batched cycle keeps the rest of the batch's signals
   reportable per the Validator's per-criterion JSON verdicts (Part 1
   territory; not changed here).
3. **`templates/progress.md` carries a `plan:` block.**
   The per-cycle schema includes a `plan:` block with fields:
   `cycle: <N>`, `failing_criteria_read: [<id>...]`,
   `coupled_groups: [{group_id, criteria: [<id>...], shared_files:
   [<path>...]} ...]`, `change_set: {<file>: <one-line intent>}`,
   `citing_criterion: <id> | citing_criteria: [<id>...]`. The block
   is required for every cycle that produces edits.
4. **Smoke / fixture test verifies plan presence.**
   `tests/smoke/perf-quickwins-part-2.test.sh` runs `/yoke:implement`
   against a 2-criterion fixture spec (criteria coupled by shared file)
   and asserts: (a) the latest cycle's `progress.md` contains a
   populated `plan:` block matching the schema, (b)
   `coupled_groups[0].criteria` has length ≥ 2 when the fixture
   exercises the coupling case. Wraps in `timeout 600`.
5. **Craftsmanship gate.**
   Generator authority preserved per `patterns/roles.md` (still no
   canonical-memory writes, still task memory scope, still no upstream
   artifact modification); no `conventions.md` Don't violated; persona
   change does not introduce a new manifesto invariant; the
   `progress.md` schema change is backward-compatible (older snapshots
   without `plan:` are still readable; absence treated as "not yet
   populated").

## Scope

In scope:

- `agents/generator.md` — rewrite "Persona" + "Behaviors → Always" to
  encode plan-first + coupling heuristic + batched-cycle license.
- `templates/progress.md` — add `plan:` block to the per-cycle schema;
  document fields inline.
- `tests/smoke/perf-quickwins-part-2.test.sh` — new fixture-driven
  smoke test with the 2 assertions above and `timeout 600`.

The fixture acceptance contract used by the smoke test lives under
`tests/fixtures/perf-quickwins-part-2/` (small enough to count as a
test-asset rather than a 4th source file).

## Anti-scope

- **Not** changing Generator's read/write authorities.
- **Not** changing the Validator's per-criterion verdict shape.
- **Not** changing the parallel-spawn architecture or any human Trigger.
- **Not** adding a non-deterministic step (the `plan:` block is
  schema-deterministic; the Generator's content inside it is LLM-driven
  but the structural assertion is testable).
- **Not** changing `agents/orchestrator.md` (Part 3 territory).
- **Not** changing sensor execution (Part 1 territory).
- **Not** introducing a stagnation early-exit heuristic. If a batched
  cycle fails to clear all targeted criteria, the existing ralph-loop
  hard-bound semantics handle it.
- **Not** rewriting the `progress.md` schema beyond the additive
  `plan:` block (existing fields stay).

## Technical Decisions

### Persona changes are prompt-engineering, not protocol-engineering

The functional contract in `patterns/roles.md` and the file-ownership
rules in `agents/generator.md`'s Memory scope / Allowed tools sections
are **unchanged**. What changes is the persona's instinct: from
"patch the latest reported violation" to "read all failing criteria,
plan the change set, then edit". The risk is bounded: an LLM that
ignores the new persona instructions degrades to current behavior, not
worse.

### Coupling heuristic: overlapping file sets

Two heuristics signal coupling in v0:

1. **Tech-Spec-derived:** the Tech Spec task that owns the criteria
   names overlapping files in its "files affected" or scope section.
   Generator reads the active Tech Spec and uses task-level grouping.
2. **Sensor-evidence-derived:** the cycle-N-1 snapshot's violation
   `location:` fields (from `patterns/sensors.md`'s structured output)
   share file paths.

Either signal triggers grouping. Neither alone is sufficient for
batching unless the Generator's plan step explicitly names a coherent
change set across the group. Conservative bias: when in doubt, don't
batch.

### `plan:` block over a separate `plan.md`

A separate planning artifact would create a new file-ownership contract
(who reads it, who appends, lifetime). Folding the plan into the
existing per-cycle entry of `progress.md` reuses Generator's existing
write authority and keeps the artifact count flat. Trade-off: each
cycle's `progress.md` entry grows; acceptable, the Validator already
reads progress for context.

### Schema fields are additive

`templates/progress.md`'s existing schema (cycle id, citing criterion,
status, etc.) is preserved verbatim. The `plan:` block is appended.
Older snapshots (pre-Part-2) remain valid; consumers treat
`plan: null` or absent as "no plan written" — backward compatible by
construction.

### Smoke-test fixture is real, not synthetic

Use a 2-criterion fixture where both criteria fail on the same file
(e.g., a function missing two unrelated branches that two BDD
scenarios exercise). This is the smallest example that meaningfully
tests coupling without being a one-criterion task. The fixture lives
under `tests/fixtures/perf-quickwins-part-2/` and is reused by future
parts if needed.

## Applicable Patterns

- `patterns/roles.md` — Generator role contract preserved (no new
  authority, no new memory tier, no new write surface). The persona
  rewrite sharpens an existing instinct.
- `patterns/ralph-loop.md` — cycle structure unchanged; the
  Generator's deterministic-vs-agentic placement (still agentic node,
  still per-cycle) is preserved. The plan step is part of the
  Generator's agentic contribution; not promoted to a separate
  deterministic node.
- `patterns/sensors.md` — sensor evidence (`location:` field) is the
  data source for the coupling heuristic; no schema change needed on
  the sensor side.
- `conventions.md` (Cross-cutting principles → "Shift feedback left")
  — plan-first reduces wasted cycles, which is the same principle at
  the agent-instinct level.

No new pattern. The persona rewrite + `plan:` block could graduate
into a pattern (`patterns/generator-plan-first.md`) if v0 data shows
the cycle-count drop is durable; defer that decision to post-v0
audit.

## Risks

- **R1: LLM ignores the persona instructions.**
  *What can go wrong:* the Generator writes a stub `plan:` block to
  satisfy the schema and continues one-criterion-at-a-time patching
  underneath, defeating the win.
  *Mitigation:* the smoke test asserts on `coupled_groups` having
  length ≥ 2 when the fixture exercises coupling; a stub pass is
  caught. Beyond v0, capture cycle-count delta in the audit
  (`.vibeflow/audits/`) — if cycle count doesn't drop, the persona
  prompt is the suspect.
- **R2: Generator over-batches and a failure cascade obscures
  signal.**
  *What can go wrong:* the Generator batches 4 criteria, breaks one,
  and the Validator's per-criterion verdicts now span passes and
  fails for the same edit — harder to attribute.
  *Mitigation:* per-criterion JSON verdicts (Validator's existing
  structured output, `agents/validator.md:38-50`) already attribute
  each verdict to a specific criterion. A failure inside a batch is
  reported per criterion. The coordinator's MERGE-READY check still
  requires all-pass, so over-batching loses cycles, not safety. The
  conservative coupling heuristic (overlapping files only) bounds the
  blast radius.
- **R3: `plan:` block bloats `progress.md` for long-running tasks.**
  *What can go wrong:* a 20-cycle task accumulates 20 plan blocks;
  reading `progress.md` becomes expensive.
  *Mitigation:* cycle-level entries are already append-only;
  `agents/validator.md` and `agents/orchestrator.md` reads are
  scoped to the latest cycle in practice. If file size becomes a
  problem, prune past plan blocks at hook time
  (`hooks/post-iteration.sh`). Defer to post-v0.
- **R4: Coupling heuristic produces false positives.**
  *What can go wrong:* two criteria touch the same file via
  unrelated functions; the Generator batches and the second
  intent contradicts the first.
  *Mitigation:* coupling-by-file is necessary but not sufficient —
  the Generator's plan step must name a coherent change set. The
  smoke test's fixture is calibrated to a true-positive case;
  field reports of false positives become canonical-memory candidates
  (heuristic refinement under Model C, not in this part).

## Dependencies

None. This part is independently implementable. Can land before,
after, or in parallel with Parts 1 and 3.
