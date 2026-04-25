---
name: implement
description: >
  Phase 4 — adversarial ralph loop. Spawns the Generator, Validator, and
  Orchestrator subagents concurrently each cycle (single Task batch) and
  iterates against the binding Acceptance Contract until every criterion
  passes or the loop pauses for human arbitration. Sprint contracts on
  consensus persist to `.yoke/contracts/<slug>.md`; runtime state under
  `.yoke/runtime/`. At loop termination, issues
  one final Orchestrator call with `mode=canonize` to apply the
  five-criteria filter and propose Model C writes to canonical memory.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /yoke:implement — Phase 4 (parallel ralph loop, v1.1.0)

Drive Generator ↔ Validator cycles inside the envelope of the binding
Acceptance Contract, with the Orchestrator subagent consulting
canonical memory live and owning the canonization handoff at
termination.

> **v1.1.0 architectural note.** This skill no longer routes through
> an "Orchestrator skill in runtime-coordinator mode". Instead, it is
> a **deterministic coordinator** that spawns three runtime subagents
> (`agents/generator.md`, `agents/validator.md`,
> `agents/orchestrator.md`) **in parallel** via a single Task batch
> per cycle. No subagent spawns another. At loop termination the skill
> issues one more Orchestrator call with `mode=canonize` to perform
> the canonization handoff.

## Process

### 1. Pre-flight (deterministic)

- Source `lib/working-memory/paths.sh`. All paths below resolve through
  `wm_*_path` helpers; the active task slug comes from `.yoke/.current`
  via `wm_active_slug`.
- Run `lib/ralph-loop/orchestrate.sh preflight`. The script verifies:
  - `.yoke/config.yaml` exists.
  - `.yoke/.current` exists and points at a valid slug.
  - `wm_prd_path "$slug"`, `wm_tech_spec_path "$slug"`, and
    `wm_acceptance_contract_path "$slug"` all exist and carry
    `Status: approved` (PRD/Tech Spec) or `Status: ratified` (Contract).
  - On any missing pre-condition, the script aborts with a clear
    message (exit codes 3 or 4).
- Run `hooks/pre-implementation.sh`.
- Ensure `.yoke/runtime/` and `.yoke/contracts/` exist (`mkdir -p`).
  Initialize `wm_progress_path` (`.yoke/runtime/progress.md`),
  `wm_contracts_path "$slug"` (`.yoke/contracts/<slug>.md`), and
  `wm_query_trace_path "$slug"` (`.yoke/query-traces/<slug>.md`) from
  `templates/progress.md`, `templates/contracts.md`, and an empty
  `# Query trace` header respectively if they don't exist (cycle 0
  entries).

### 2. Cycle loop

For each cycle (numbered starting at 1):

1. **Concurrent subagent batch (single agentic turn, 3 Task calls).**
   In a single assistant turn, issue **three concurrent Task calls**
   spawning `agents/generator.md`, `agents/validator.md`, and
   `agents/orchestrator.md` simultaneously. Each receives **disjoint
   inputs** read from the freshest snapshot of working memory at
   spawn time.

   - **Generator (`agents/generator.md`)** — input:
     - Approved upstream artifacts at `wm_prd_path`,
       `wm_tech_spec_path`, `wm_acceptance_contract_path` (read-only).
     - Current runtime progress at `wm_progress_path` (last cycle's
       state).
     - Current sprint contracts at `wm_contracts_path "$slug"`.
     - Current query trace at `wm_query_trace_path "$slug"`
       (Orchestrator's prior consult output for this loop).
     - Last `verify-acceptance.sh` snapshot from
       `$(wm_snapshots_dir)/cycle-<N-1>.yaml` (if any).

     Writes code targeting the next failing Acceptance Contract
     criterion; persists `wm_progress_path` at end of turn.

   - **Validator (`agents/validator.md`)** — input:
     - Approved Acceptance Contract at `wm_acceptance_contract_path`.
     - Last `verify-acceptance.sh` snapshot from
       `$(wm_snapshots_dir)/cycle-<N-1>.yaml`.
     - Current sprint contracts at `wm_contracts_path` and runtime
       progress at `wm_progress_path` (read-only).
     - Current query trace at `wm_query_trace_path`.

     Emits structured JSON verdicts per criterion against the
     freshest snapshot's sensor output; appends sprint contracts to
     `wm_contracts_path` only on consensus events (post-Validator
     verdict, never concurrent with Generator's writes).

   - **Orchestrator (`agents/orchestrator.md`)** — input:
     - `mode=consult+monitor`, `cycle=<N>`, `slug=<active slug>`.
     - Current `wm_progress_path`, `wm_contracts_path`,
       `wm_query_trace_path`.
     - Last `verify-acceptance.sh` snapshot.

     Consults canonical memory via
     `lib/canonical-memory/query.sh` for patterns relevant to the
     next failing criterion; appends to `wm_query_trace_path`.
     Monitors for Generator↔Validator divergence; on divergence
     invokes `lib/ralph-loop/escalate.sh` to emit the Trigger-4
     packet (written to `wm_trigger4_packet_path`).

   Issue the three Task calls in a **single assistant turn** so
   they execute concurrently. Per-agent file-write contracts (in
   `agents/*.md`) prevent within-batch collisions: Generator owns
   the progress file, Orchestrator owns the query trace, and the
   contracts file is appended only on consensus events post-batch.

2. **Sensor execution (deterministic).** Run
   `hooks/verify-acceptance.sh` (default arg resolves to
   `wm_acceptance_contract_path`) to capture cycle N's
   post-Generator sensor state. Capture the structured YAML output.

3. **Contradiction check (deterministic).** Run
   `lib/ralph-loop/orchestrate.sh check-contradiction`. If a sprint
   contract textually contradicts an Acceptance Contract criterion
   (heuristic: contains a relax/remove/skip/disable/bypass/ignore
   verb together with a criterion identifier), the script exits 10
   and the loop pauses with a clear message: "Sprint contract
   contradicts Acceptance Contract. Pausing for human arbitration."

4. **Persist (deterministic).** Run `hooks/post-iteration.sh`. The
   hook:
   - Increments the cycle counter at `wm_cycle_counter_path`
     (`.yoke/runtime/.cycle-counter`).
   - Snapshots `verify-acceptance.sh` output to
     `$(wm_snapshots_dir)/cycle-<N>.yaml`.

5. **Hard-bound check (deterministic).** Run
   `hooks/check-hard-bounds.sh`. If cycles, timeout, or token
   budget is exceeded, the hook invokes
   `lib/ralph-loop/escalate.sh --reason hard-bound` and exits 10.
   The skill treats this as a pause-with-arbitration-packet.

6. **Stop check.** If every criterion in the Acceptance Contract
   has `status: pass` in the latest sensor output AND no
   `divergence` verdict from the Validator, return MERGE-READY and
   advance to the canonization handoff (step 3). Otherwise, continue
   to the next cycle.

### 3. Termination handoff — Orchestrator canonize call (single agentic call)

The handoff fires once when the loop terminator hits — whether the
loop converged (MERGE-READY) or paused (Trigger-4 / hard-bound /
infeasibility). Issue a **single Orchestrator-only Task call** with
input `mode=canonize`:

- Input includes `wm_progress_path`, `wm_contracts_path`,
  `wm_query_trace_path`, all `$(wm_snapshots_dir)/cycle-*.yaml`,
  and the loop's termination reason
  (`merge-ready` | `divergence` | `contract-conflict` |
  `hard-bound` | `infeasibility`).
- Orchestrator (in canonize mode) invokes `/yoke:preserve` via the
  Skill tool, passing the active task's `.yoke/<task-slug>/` path
  and `--from-orchestrator`. `/yoke:preserve` invokes
  `lib/canonical-memory/canonization-criteria.sh` to apply the
  five-criterion cascade, reads each candidate's `impact_level`,
  and opens PRs per Model C.
- Per Model C: low-impact PRs auto-merge after CI; medium PRs open
  with veto window; high-impact and regulatory PRs surface for
  synchronous human review without blocking the skill's exit.
- This is the **only** canonical-memory write path during the loop.
  Mid-loop Orchestrator invocations (consult / monitor mode) never
  invoke `/yoke:preserve`.

Exit with the loop's termination reason and a one-line summary of
PRs opened (count + URLs).

### 4. Termination paths

- **All criteria pass** → loop returns MERGE-READY; canonize handoff
  fires (Orchestrator invokes `/yoke:preserve` via the Skill tool).
  Print: "Merge-ready. Canonization summary: <count> PRs opened."
  `/yoke:preserve` can also be invoked manually for re-canonization
  (e.g. after a model upgrade or to re-evaluate stale working memory).
- **Sprint contract contradicts Acceptance Contract** → invoke
  `lib/ralph-loop/escalate.sh --reason contract-conflict`; emits
  Trigger-4 packet; canonize handoff still fires (with termination
  reason `contract-conflict`) so partial learnings are not lost.
- **Divergence verdict from Validator** → invoke
  `lib/ralph-loop/escalate.sh --reason divergence --category <quality-policies-broken|technical-infeasibility|business-conflict|requires-contract-modification>`;
  Trigger-4 packet; canonize handoff fires.
- **Hard bound reached** → `check-hard-bounds.sh` invokes
  `escalate.sh --reason hard-bound` and exits 10; canonize handoff
  fires (the loop's partial state is the canonization signal).
- **Fundamental infeasibility detected by Generator** → `escalate.sh
  --reason infeasibility`; canonize handoff fires.

The Trigger-4 packet is non-coalescable with Triggers 1, 2, 3, 5 —
see `.vibeflow/patterns/human-triggers.md`.

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/.current` exists and points at a valid slug.
- `.yoke/prds/<slug>.md` (approved), `.yoke/tech-specs/<slug>.md`
  (approved), `.yoke/acceptance-contracts/<slug>.md` (ratified).

## Output contract

- Exit 0 with merge-ready code + canonize summary on full
  convergence.
- Exit non-zero with a clear pause/abort message on divergence,
  contradiction, hard-bound, or pre-condition failure. The canonize
  handoff still fires before exit (except on pre-condition failure).

## Anti-patterns

- Do NOT spawn the three subagents sequentially. They must launch in
  a **single assistant turn with three concurrent Task calls** so
  they execute in parallel.
- Do NOT let the subagents share context. Each Task call passes only
  the explicit inputs listed in step 2; communication is via
  working-memory files.
- Do NOT invoke `/yoke:preserve` mid-loop. Canonization fires only
  at termination via the Orchestrator's canonize-mode handoff.
  Canonical-memory writes happen only in the termination handoff
  (step 3).
- Do NOT skip `hooks/verify-acceptance.sh` between cycles — sensor
  output is the structured channel through which the Validator
  judges the next cycle.
- Do NOT silently relax the Acceptance Contract. Sprint contracts
  that contradict the Contract pause the loop.
- Do NOT proceed past 5–8 cycles without an external `timeout`
  before Sprint 6's hard bounds are wired.
- Do NOT spawn `agents/orchestrator.md` recursively from inside any
  subagent — only this skill spawns subagents.

## See also

- `.vibeflow/patterns/ralph-loop.md`.
- `.vibeflow/patterns/roles.md`.
- `.vibeflow/patterns/model-c-governance.md` — termination-time
  write protocol.
- `agents/generator.md`, `agents/validator.md`,
  `agents/orchestrator.md`.
- `lib/ralph-loop/orchestrate.sh`,
  `lib/ralph-loop/escalate.sh`,
  `lib/canonical-memory/canonization-criteria.sh` (invoked from
  inside `/yoke:preserve`).
- `skills/ask/SKILL.md` (canonical-memory reads — Part 3 of the
  bedrock canonical-memory port retired `query.sh`).
- `skills/preserve/SKILL.md` (canonical-memory writes — Part 4
  retired `propose-write.sh`).
- `hooks/pre-implementation.sh`, `hooks/post-iteration.sh`,
  `hooks/verify-acceptance.sh`, `hooks/check-hard-bounds.sh`.
