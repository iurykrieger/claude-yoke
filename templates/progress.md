# Progress

> Written by the Implementation Agent at the end of every ralph-loop
> cycle. The schema is YAML inside markdown for diff-friendliness.
> The agent appends one block per cycle.

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
- notes: "<free text — keep tight>"

<!-- Subsequent cycles append below this line, one `## Cycle <N>` block per cycle. -->
