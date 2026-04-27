# Progress

> Written by the Implementation Agent at the end of every ralph-loop
> cycle. The schema is YAML inside markdown for diff-friendliness.
> The agent appends one block per cycle.
>
> The optional `plan:` block (added in v0.7.0 by perf-quickwins Part 2)
> records the Generator's plan-first reasoning before any edits land.
> When the Generator batches coupled criteria within a single cycle,
> the `coupled_groups` field captures the grouping; `change_set` names
> the files plus the intent. Older snapshots without `plan:` remain
> valid — absent or null is treated as "not yet populated".

## Cycle 0 — initial state
- timestamp: "<iso8601>"
- next_step: "<plain-text description>"
- files_touched: []
- sensor_feedback_consumed: []
- contract_consensus_reached: false
- citing_criterion: ""

## Cycle 1 — <short label>
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

<!-- Subsequent cycles append below this line, one `## Cycle <N>` block per cycle. -->

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
>   Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`.
