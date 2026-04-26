---
tags: [governance, authority, ratification, git-native, impact-class, model-c]
modules: []
applies_to: [orchestrator, canonical-memory, ratification-flow, pull-requests]
confidence: validated
---
# Pattern: Model C Governance — Contextual Authority by Impact Class

<!-- vibeflow:auto:start -->
## What
Model C is Yoke's governance scheme for canonical-memory writes: **authority
varies by the impact class of the proposition, not by who proposes it**. Low
impact auto-applies, medium notifies-and-applies with a veto window, high
requires synchronous human ratification, regulatory MUST policies require
Compliance. The Orchestrator is the only writer; Model C decides when and
how each proposition becomes doctrine.

## Where
Applied at every write to canonical memory. The protocol is **git-native** —
the Orchestrator opens a pull request on the substrate repository and
ratification is the merge itself.

## The Pattern

### Authority matrix

| Entity | May propose | May write canonical memory | May ratify |
| :--- | :--- | :--- | :--- |
| Generator (runtime subagent) | — | No | — |
| Validator (runtime subagent) | — | No | — |
| Spec-phase skills (Generator/Validator persona inline) | — | No | — |
| Orchestrator (runtime subagent) | Yes | Yes (canonize mode only, with Model C threshold) | — |
| Individual engineer | Yes (via PR) | No direct | Local policies |
| Harness engineer | Yes | Yes | Everything except global policies |
| Platform / DevEx | — | — | Global policies, new templates |
| Compliance / Security | — | — | Regulatory MUST policies |

The Orchestrator's authority varies by impact class:
- **Divergence patterns** (low) → auto-apply.
- **Template refinements** (medium) → notify-and-apply with veto window.
- **New MUST policies** (high) → synchronous human ratification required.
- **Regulatory MUST policies** → only Compliance ratifies; Orchestrator never writes directly.

### Git-native write protocol

Canonical-memory writes happen as PRs on the substrate repo. Ratification is the merge.

| Impact | PR behavior |
| :--- | :--- |
| Low | Auto-merge after passing checks |
| Medium | Veto window — auto-merge after a configured quiet period without objection |
| High | Synchronous approval required before merge |
| Regulatory | Synchronous approval by Compliance only |

Properties this gives for free:
- Native versioning, diff and history.
- Human ratification reuses the existing PR-review workflow.
- Rollback is `git revert`.
- Full structural auditability in PR history.

### Canonization criteria (cascading filter before proposing)
The Orchestrator applies these in order before opening a PR:
1. **Repeatability** — has the pattern manifested ≥ N times?
2. **Generality** — does the learning apply to ≥ M scopes?
3. **Stability** — has the pattern held over a minimum period?
4. **Impact** — does absence of the learning produce observable cost?
5. **Non-contradiction** — does the learning not contradict existing canonical memory?

If 1–4 are true and 5 is true → propose a write. Auto-apply threshold is set
by Model C.

## Rules
- Every canonical-memory write is a PR. There is no out-of-band write path.
- The Orchestrator never bypasses Model C, even for its own observations.
- Regulatory MUST policies cannot be auto-applied, even when low-volume. The Orchestrator can propose them but cannot ratify them.
- Auto-apply thresholds are configurable per organization and recalibrated against operational data (auto-applied propositions later reverted vs high-impact propositions rejected by humans).
- Veto windows are visible — anyone in the read circle of canonical memory can object and block the auto-merge.
- A failed criterion among 1–4 does not block proposing; it lowers the impact class. Failed criterion 5 (contradiction) blocks the proposition until the contradiction is resolved.

## Examples from this codebase
> Repository is empty. Expected PR shape for canonical-memory updates:

```
PR title: [canonize] template-refinement: payment-reversal/sprint-contract-shape
Labels: impact:medium, type:template-refinement
Author: orchestrator-bot

Summary
-------
Sprint contracts for reversal flows consistently include a 'compensating-event' clause.
Observed in 7 tasks across 2 squads since 2026-03-01.

Traceability
------------
- tasks/2026-03-payment-reversal/contracts.md
- tasks/2026-03-refund-correction/contracts.md
- ... (5 more)

Canonization criteria
---------------------
- Repeatability: 7/7 ✓
- Generality: 2 squads ✓
- Stability: 6+ weeks ✓
- Impact: avoids 2 known divergences (Trigger 4 history) ✓
- Non-contradiction: ✓ (no conflicting policy)

Veto window: 72h
Auto-merge: scheduled for 2026-04-27 14:00 UTC
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- Direct writes to the substrate repo bypassing the Orchestrator — destroys auditability.
- Auto-applying high-impact or regulatory writes — defeats the safety property of Model C.
- Stripping the veto window for "speed" — removes the only check between an over-eager Orchestrator and doctrine.
- Hand-tuning auto-apply thresholds without operational data — produces either stagnation (too high) or pollution (too low).
- Treating Compliance ratification as a rubber-stamp — measure modification rate; if zero, the gate is decorative.

## Implementation Mapping

Updated by Part 4 of the bedrock canonical-memory port (2026-04-25).
Earlier versions named `lib/canonical-memory/propose-write.sh` as the
write entry; that primitive is retired in favor of the `/yoke:preserve`
skill.

- **Authority logic** — Model C impact-class routing now lives inside
  `skills/preserve/SKILL.md` Phase 3 (proposal + routing). The
  Orchestrator subagent invokes `/yoke:preserve` at loop termination;
  it no longer classifies impact itself.
- **Write entry point** — `/yoke:preserve` Phase 6:
  - Low impact → PR with `--auto-merge` after CI checks.
  - Medium impact → PR with veto window (default 24h, configurable via
    the memory's `.yoke-memory/config.json` `model_c.veto_window_hours`);
    auto-merge after window closes.
  - High impact → PR with `--no-auto-merge`; synchronous human approval
    required.
  - Regulatory → PR with `--no-auto-merge`; routed to Compliance via
    CODEOWNERS in the canonical-memory repo.
- **Canonization criteria** — `lib/canonical-memory/canonization-criteria.sh`
  applies the five filters in cascade (repeatability, generality,
  stability, impact, non-contradiction). It is invoked from inside
  `/yoke:preserve` Phase 3.2 (when called via `--from-orchestrator`),
  not from the Orchestrator subagent directly.
- **PR labels** — every PR carries `yoke-proposal` and
  `impact-{low,medium,high,regulatory}` labels for fleet-wide
  auditability.
- **Dependency** — `gh` CLI installed and authenticated when the
  memory's `git.strategy` is `commit-push-pr` (Yoke default). Falls
  back to `commit-push` with a warning when `gh` is missing.

Note: `lib/canonical-memory/propose-write.sh` and `skills/canonize/`
were deleted in Part 4. `/yoke:preserve` covers the canonize and
re-canonize use cases; manual re-canonization is `/yoke:preserve`
invoked without `--from-orchestrator`.
