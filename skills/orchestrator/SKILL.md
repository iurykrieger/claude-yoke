---
name: orchestrator
description: >
  The Orchestrator skill — three operating modes for canonical memory.
  Mediator mode services /yoke:ask queries from Generator/Validator (writes
  .yoke/query-traces/<slug>.md). Runtime coordinator mode is invoked by /yoke:implement
  to spawn Implementation/Validation Agents. Canonizer mode is invoked by
  /yoke:canonize to apply the five canonization criteria and propose writes
  via Model C. Sole writer of canonical memory.
argument-hint: "<mode> [args]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /yoke:orchestrator — Orchestrator skill (three modes)

> **Architectural note (PRD v0 amendment).** The Orchestrator is a *skill*,
> not a subagent. Risk R1 (Claude Code subagent depth) is sidestepped:
> the Orchestrator invokes the four agent subagents (Generator, Validator,
> Implementation Agent, Validation Agent) via the Task tool when needed.
> No subagent spawns another subagent. v0.5.0 implements all three modes
> with the **low-impact** Model C path; medium/high-impact paths and
> progressive disclosure ship in Sprint 6.

## Three modes

The Orchestrator declares its current mode explicitly when invoked. Mode
declarations write to `.yoke/query-traces/<slug>.md` so traces show provenance for
every operation.

### Mode A — Mediator

Invoked by `/yoke:ask` (and indirectly by `/yoke:discover`,
`/yoke:tech-spec`, `/yoke:acceptance-contract` when those skills route
canonical-memory queries through `/yoke:ask`). The Orchestrator services
queries from spec-phase agents:

- Reads from the cached canonical-memory repo (`~/.cache/yoke/canonical/<slug>/`).
- Returns matching entries (text grep in v0.5.0; subgraph traversal in
  Sprint 6).
- Writes the query, result count, and invoker (when known) to
  `.yoke/query-traces/<slug>.md` for audit and future canonization signal.
- **Detects and flags** any attempt by Generator/Validator to bypass the
  Orchestrator and read canonical memory directly. In v0.5.0, bypass
  detection is conservative: every legitimate query writes a trace
  entry; absence of a trace entry for a query the agent claims to have
  consulted is the bypass signal.

### Mode B — Runtime coordinator

Invoked by `/yoke:implement` (Phase 4). The Orchestrator coordinates the
Implementation Agent ↔ Validation Agent ralph loop:

- Spawns each agent via the Task tool with disjoint inputs.
- Runs `hooks/verify-acceptance.sh` between agent turns.
- Calls `lib/ralph-loop/orchestrate.sh check-contradiction` after each
  cycle.
- Persists state via `hooks/post-iteration.sh`.
- See `skills/implement/SKILL.md` for the full Phase-4 contract.

This mode in v0.5.0 is **read-only** with respect to canonical memory; it
does not propose canonization mid-loop. Canonization happens in Mode C
after the loop converges.

### Mode C — Canonizer

Invoked by `/yoke:canonize` (Phase 5). The Orchestrator reads working
memory after a successful task and proposes writes to canonical memory
under Model C:

- Reads runtime + archive artifacts via `lib/working-memory/paths.sh`:
  `wm_progress_path` (`.yoke/runtime/progress.md`),
  `wm_contracts_path` (`.yoke/contracts/<slug>.md`), and
  `wm_query_trace_path` (`.yoke/query-traces/<slug>.md`).
- Invokes `lib/canonical-memory/canonization-criteria.sh` to apply the
  five-criterion cascade (repeatability / generality / stability / impact /
  non-contradiction).
- For each candidate that passes 1–4 and is non-contradicting (criterion 5),
  invokes `lib/canonical-memory/propose-write.sh` to open a PR on the
  canonical-memory repo.
- v0.5.0: only **low-impact** propositions are auto-applied (auto-merge
  after CI checks). Medium/high-impact paths ship in Sprint 6 (veto
  window / synchronous ratification).
- v0.5.0 tests target a **TEST canonical-memory repo** (or run with
  `--dry-run`) to avoid polluting production memory before the
  human-veto path lands.

## Mode declarations

Every Orchestrator invocation begins with a single-line mode declaration
on stdout, also written to `.yoke/query-traces/<slug>.md`:

```
[orchestrator:mediator] query="<term>" subgraph_depth=1
[orchestrator:runtime-coordinator] cycle=<N>
[orchestrator:canonizer] candidates=<count>
```

If you invoke the Orchestrator without a mode declaration, that is a
self-bug — abort and re-prompt with the mode token explicit.

## Impact classification rules (Sprint 6+ — full Model C)

The Orchestrator (Canonizer mode) classifies every candidate's impact
before invoking `propose-write.sh`. Classification is keyword-based and
operates on `tolower(topic + " " + decision)` of the candidate:

| Impact | Trigger keywords | PR behavior |
| :--- | :--- | :--- |
| `regulatory` | `regulatory`, `gdpr`, `lgpd`, `pci`, `hipaa`, `soc2`, `compliance` | `auto-merge: never`; routed to Compliance via CODEOWNERS in the canonical repo |
| `high` | `policy`, `must` (word-bounded), `require` | `auto-merge: never`; synchronous human approval required |
| `medium` | `template`, `convention`, `naming` | PR comment announces veto window (default 24 h); auto-merge after window closes |
| `low` | (default — no high/medium/regulatory keyword match) | Auto-merge after CI checks |

The classification is intentionally conservative: keyword overlap with a
higher class wins. For example, "compliance template" classifies as
`regulatory` (regulatory > medium).

Veto-window length and auto-merge defaults are configurable via
`.yoke/config.yaml` overrides under `model_c.veto_window_hours`.

`propose-write.sh` rejects unknown impact strings with exit code 4.
Operator overrides (manually editing the candidate's impact value) are
audited via the canonical-memory PR history.

## Authority

The Orchestrator is the **sole writer of canonical memory** under Model C.
No other agent or skill may propose writes; no other agent may write
directly. v0.5.0 enforces:

- Generator and Validator subagents declare in their prompts that they
  read canonical memory only via `/yoke:ask` (which routes through the
  Orchestrator in Mediator mode).
- `/yoke:ask` writes every query to `.yoke/query-traces/<slug>.md`. Bypass
  attempts (direct grep of the substrate by spec-phase agents) are
  detectable from the trace's absence — if a Generator claims to have
  consulted canonical memory but no trace entry exists for that query,
  that is a bypass.

## Lineage

The canonical-memory primitives under `lib/canonical-memory/` are forked
one-time at the start of Sprint 5 from
<https://github.com/iurykrieger/claude-bedrock>. Yoke layers the
five-criteria filter and Model C impact classes on top of Bedrock's
read/write/graph primitives. The Orchestrator skill itself is
Yoke-native (not in upstream Bedrock). Per-script lineage will be
recorded in `docs/lineage.md` at Sprint 8.

## Anti-patterns

- Do NOT invoke the Orchestrator without an explicit mode declaration.
  Mode is the audit trail.
- Do NOT mix modes in a single invocation. One mode per Task call.
- Do NOT write canonical memory outside the Canonizer mode + Model C
  path. v0.5.0's only allowed write surface is `propose-write.sh`.
- Do NOT auto-apply medium/high/regulatory propositions in v0.5.0 — only
  low-impact. Sprint 6 ships the veto-window and sync-ratify paths.
- Do NOT operate against the production canonical-memory repo in tests.
  Use a test substrate (configured via `.yoke/config.yaml`'s
  `canonical_memory.url`) or `--dry-run` until Sprint 6 ships the
  human-veto path.

## See also

- `.vibeflow/patterns/roles.md` — Orchestrator role contract.
- `.vibeflow/patterns/model-c-governance.md` — write protocol.
- `.vibeflow/patterns/memory-model.md` — canonical-memory format.
- `lib/canonical-memory/query.sh` — Mediator-mode read primitive.
- `lib/canonical-memory/canonization-criteria.sh` — Canonizer-mode filter.
- `lib/canonical-memory/propose-write.sh` — Canonizer-mode write primitive.
- `skills/canonize/SKILL.md`, `skills/ask/SKILL.md`,
  `skills/implement/SKILL.md` — phase-skill consumers.
