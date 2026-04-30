---
slug: <slug>
current_sprint: "01"
completed_sprints: []
total_sprints: <N>
cycle_count: 0
---

# Progress

> Written by the Implementation Agent at the end of every ralph-loop
> cycle. The schema is YAML inside markdown for diff-friendliness.
> The agent appends one cycle block per cycle inside the active
> sprint's H2 section.
>
> The frontmatter carries the sprint-walk pointer (sprint-as-cycle
> PRD, 2026-04-27): `current_sprint:` (zero-padded 2 digits — the
> sprint id whose file is the cycle's working set), `completed_sprints:`
> (array of zero-padded sprint ids that have converged), `total_sprints:`
> (count of sprint files for the active slug), `cycle_count:` (cycles
> consumed in the active sprint, resets to 0 at sprint boundaries —
> per-sprint hard bound is ≤ 8 per `concepts/yoke-pattern-ralph-loop`).
>
> Body shape: one `## Sprint <NN>` H2 per sprint, in sprint order.
> Inside each sprint H2, one `### Cycle <C>` H3 per cycle in that
> sprint. The cycle counter resets at every sprint boundary; the
> H3 entries inside `## Sprint 02` start over at `### Cycle 1`. The
> file remains a singleton — never split into per-sprint progress
> files (PRD anti-scope).
>
> The optional `plan:` block (added in v0.7.0 by perf-quickwins Part 2)
> records the Generator's plan-first reasoning before any edits land.
> When the Generator batches coupled criteria within a single cycle,
> the `coupled_groups` field captures the grouping; `change_set` names
> the files plus the intent. Older snapshots without `plan:` remain
> valid — absent or null is treated as "not yet populated".

## Sprint 01

### Cycle 0 — initial state
- timestamp: "<iso8601>"
- next_step: "<plain-text description>"
- files_touched: []
- sensor_feedback_consumed: []
- contract_consensus_reached: false
- citing_criterion: ""

### Cycle 1 — <short label>
- timestamp: "<iso8601>"
- next_step: "<what the Implementation Agent decided>"
- files_touched:
    - "<path>"
- sensor_feedback_consumed:
    - "<sensor name from the previous cycle's verify-acceptance output>"
- contract_consensus_reached: <true | false>
- citing_criterion: "<FR-N | Scenario N>"
- citing_criteria: ["<FR-N>", "<Scenario N>"]   # optional; populated only when the cycle batches coupled criteria
- plan:
    cycle: <N>
    failing_criteria_read:
      - "<FR-N | Scenario N>"
    coupled_groups:
      - group_id: g1
        criteria: ["<FR-N>", "<FR-M>"]
        shared_files: ["<path>"]
        coupling_signal: "<tech-spec-overlap | sensor-evidence-overlap | both>"
    change_set:
      "<path>": "<one-line intent>"
- schedule_next:
    sensors: ["<sensor-id>"]                    # optional; explicit ids
    tiers: ["cheap"]                            # at least one of sensors / tiers must be non-empty
    reason: "<must cite at least one signal source — sensor id, criterion id, Tech-Spec section, or runs: history entry>"
- notes: "<free text — keep tight>"

<!-- Subsequent cycles inside this sprint append as further `### Cycle <C>` H3 entries below. When current_sprint: advances, append a new `## Sprint <NN>` H2 below this section. -->

## Sprint 02

<!-- Populated when current_sprint: advances to 02 and the first cycle of that sprint runs. cycle_count: resets to 0 at the boundary. -->

<!-- One `## Sprint <NN>` H2 per sprint, in sprint order, until completed_sprints: length equals total_sprints:. -->

> Schema notes:
>
> - `failing_criteria_read` lists every Acceptance Contract criterion the
>   Generator inspected at the start of the cycle (drawn from the latest
>   `cycle-<N-1>.yaml` snapshot's failing entries). The list MAY exceed
>   the criteria the cycle ultimately edits — reading-without-editing is
>   normal when the Generator decides not to batch.
> - `coupled_groups` is empty (or omitted) when the Generator decides the
>   failing criteria do not share a change surface and works one criterion
>   per cycle. When non-empty, every `criteria` array in the group MUST
>   contain ≥ 2 criterion ids; single-element groups are a self-bug.
> - `coupling_signal` records WHY the Generator considered the criteria
>   coupled. Allowed values: `tech-spec-overlap` (the Tech Spec task names
>   overlapping files), `sensor-evidence-overlap` (sensor violation
>   locations from the last snapshot share file paths), or `both`.
> - `change_set` is a map from file path to a one-line intent
>   ("add response-schema validation", "fix off-by-one in retry
>   counter"). It is the Generator's stated commitment for the cycle —
>   the Validator and the Orchestrator read it to attribute subsequent
>   diffs to a declared intent.
> - `citing_criteria` is an alternative to `citing_criterion`, used when
>   a cycle batches multiple coupled criteria. Exactly one of the two
>   fields MUST be populated per cycle.
> - `schedule_next` is the Validator's per-cycle scheduling decision —
>   added in v0.8.0 by sensor-cost-tiering Part 4. Persisted verbatim
>   from the Validator's verdict, it tells the coordinator which
>   sensors / tiers to run in cycle `<N+1>` (lag-by-one). At least one
>   of `sensors:` or `tiers:` MUST be non-empty; `reason:` MUST cite
>   at least one signal source by name (sensor id, criterion id,
>   Tech-Spec section, or `runs:` history entry from a per-sensor
>   file). Empty / missing `schedule_next` is a malformed verdict.
>   Source PRD: `.yoke/prds/2026-04-27-sensor-cost-tiering.md`.
