# Sprint contracts

> Co-written by the Implementation Agent and the Validation Agent
> when they reach consensus on a sub-objective interpretation.
> Sprint contracts can refine the Acceptance Contract envelope but
> never relax it. A contract that contradicts the Acceptance Contract
> pauses the loop for human arbitration (Trigger 4 in Sprint 6+; in
> v0.4.0 the loop pauses with a clear message).

## Contract <id>
- id: "<short identifier, e.g. c1>"
- topic: "<ambiguity that was resolved>"
- decision: "<the agreed interpretation>"
- rationale: "<why this resolution; cite the Acceptance Contract criterion>"
- timestamp: "<iso8601>"
- agents_involved: [implementation, validation]
- references:
    - "acceptance-contract.md#<criterion id>"
- cycle: <N>
- schedule_next:
    sensors: ["<sensor-id>"]                    # optional; explicit ids
    tiers: ["cheap"]                            # at least one of sensors / tiers must be non-empty
    reason: "<must cite at least one signal source — sensor id, criterion id, Tech-Spec section, or runs: history entry>"

<!-- Subsequent contracts append below this line, one `## Contract <id>` block per consensus reached. -->

> Schema notes:
>
> - `schedule_next` mirrors the Validator's per-cycle decision verbatim
>   (added in v0.8.0 by sensor-cost-tiering Part 4). When consensus is
>   reached on a sub-objective, the scheduling decision active at that
>   cycle is captured here for audit. At least one of `sensors:` or
>   `tiers:` MUST be non-empty; `reason:` MUST cite at least one signal
>   source. Source PRD: `.yoke/prds/2026-04-27-sensor-cost-tiering.md`.
