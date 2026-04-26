---
tags: [agents, roles, generator, validator, orchestrator, write-authority]
modules: []
applies_to: [agents, skills, prompts]
confidence: validated
---
# Pattern: Three Agentified Roles (Runtime Subagents)

<!-- vibeflow:auto:start -->
## What
Yoke structures runtime around three agentified roles with disjoint
functional objectives: **Generator** writes implementation code,
**Validator** judges conformance against determinable signals, and
**Orchestrator** mediates canonical memory live during cycles, monitors
for divergence, and owns the canonization handoff at loop termination.
Read and write authority for each role is declared explicitly — there
is no implicit access.

Spec-phase work (Phases 1–3) is performed by **skills** with embedded
persona prompts (Generator persona in `/yoke:discover` and
`/yoke:tech-spec`; Validator persona in `/yoke:acceptance-contract`).
Skills do not spawn subagents at spec phase. The human is the
adversary via Triggers 1/2/3. *Skills deliberate; subagents adapt.*

## Where
Conceptually, every task touches all three roles. Generator and
Validator runtime subagents are spawned by `/yoke:implement` in Phase
4; the Orchestrator subagent is spawned alongside them every cycle and
once more at loop termination (canonize mode). Spec-phase Generator
and Validator personas are inline in their respective skills, not
separate subagents.

## The Pattern

### Generator (runtime subagent)
Objective: turn the approved Tech Spec + Acceptance Contract into code
that satisfies every Contract criterion.
- Spawned: by `/yoke:implement` every cycle, alongside Validator and
  Orchestrator (single concurrent Task batch).
- Writes: `.yoke/progress.md` every cycle; `.yoke/contracts.md`
  jointly with the Validator on consensus events.
- Reads: upstream artifacts read-only; sensor output from
  `verify-acceptance.sh`.
- Reads canonical memory: only via `/yoke:ask` invoked through the
  Skill tool; never directly. Direct filesystem reads of the
  registered memory (cat, grep, clone, pull) are prohibited.
- Writes canonical memory: never.

### Validator (runtime subagent)
Objective: judge conformance against the binding Acceptance Contract
using declared sensors and structured verdicts.
- Spawned: by `/yoke:implement` every cycle, alongside Generator and
  Orchestrator.
- Writes: `.yoke/contracts.md` jointly with the Generator on
  consensus events. Emits structured JSON verdicts that the next cycle
  reads.
- Reads: sensor output from `verify-acceptance.sh`; upstream artifacts
  read-only.
- Reads canonical memory: only via `/yoke:ask` invoked through the
  Skill tool; never directly.
- Writes canonical memory: never.

### Orchestrator (runtime subagent — sole canonical-memory writer)
Three runtime modes:

1. **Consult.** Per cycle, alongside Generator and Validator. Invokes
   `/yoke:ask` via the Skill tool and reasons over the response
   in-conversation. The skill enforces progressive disclosure
   (≤ 15 entity reads, 1-level wikilink hop) — never the full memory.
2. **Monitor.** Per cycle. Detects Generator↔Validator divergence and
   sprint-contract / Acceptance-Contract contradictions; on detection
   invokes `lib/ralph-loop/escalate.sh` to emit the Trigger-4 packet.
3. **Canonize.** Once at loop termination. Invokes `/yoke:preserve`
   via the Skill tool, which applies the five-criterion cascade,
   classifies impact per Model C, and opens PRs against the canonical-
   memory substrate. The only canonical-memory write path during the
   loop.

The Orchestrator is the **sole writer of canonical memory** under
Model C; no other agent or skill may propose writes; no other agent
may write directly. Bypass discipline (declarative): every
canonical-memory read by Generator, Validator, or Orchestrator
**must** go through `/yoke:ask` invoked via the Skill tool; direct
filesystem reads of the registered memory are prohibited.

### Spec-phase personas (inline in skills, no subagents)
- **Generator persona** lives inline in `skills/discover/SKILL.md` and
  `skills/tech-spec/SKILL.md`. The skill drives the dialogue; the
  user-facing Claude executes.
- **Validator persona** lives inline in
  `skills/acceptance-contract/SKILL.md`. Same model.
- Both skills route canonical-memory reads through `/yoke:ask`
  (a thin skill calling `lib/canonical-memory/query.sh` directly).

## Rules
- Every read of canonical memory passes through `/yoke:ask` (spec
  phases) or the Orchestrator subagent (runtime). There is no other
  read path.
- Only the Orchestrator subagent writes to canonical memory, and
  only in canonize mode at loop termination, and only with Model C
  applied.
- Generator and Validator (runtime subagents) write freely to working
  memory inside their declared file ownership.
- The three runtime subagents are spawned in **a single concurrent
  Task batch per cycle** (1 assistant turn, 3 Task calls). Per-agent
  file-ownership contracts prevent within-batch write collisions.
- The runtime subagents must never share context. Adversarial
  separation between code generation and code judgment is by design
  — communicate only via working-memory files and
  `verify-acceptance.sh` output.
- Canonical-memory writes happen only at loop termination. Mid-loop
  writes are forbidden.
- Spec-phase skills do not spawn subagents. Their `allowed-tools`
  must not include `Task`.

## Examples from this codebase

```
agents/
├── generator.md          # runtime subagent — code generation
├── validator.md          # runtime subagent — sensor execution + verdicts
└── orchestrator.md       # runtime subagent — consult + monitor + canonize

skills/
├── discover/SKILL.md            # Generator persona inline (no subagent spawn)
├── tech-spec/SKILL.md           # Generator persona inline
├── acceptance-contract/SKILL.md # Validator persona inline
├── ask/SKILL.md                 # thin canonical-memory query skill
├── implement/SKILL.md           # spawns 3 subagents per cycle in parallel
└── canonize/SKILL.md            # manual escape hatch (spawns Orchestrator subagent)
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- Generator or Validator writing directly to canonical memory — breaks Model C, pollutes doctrine.
- Generator or Validator reading canonical memory directly, bypassing Orchestrator/`/yoke:ask` — breaks progressive disclosure, context explodes.
- A single agent doing both generation and validation — recreates the self-evaluation bias the role split exists to mitigate.
- Generator and Validator subagents sharing prompt/context — breaks adversariality.
- Treating the Orchestrator as a passive router instead of a stateful coordinator with checkpointing — runtime failures lose recovery state.
- Spawning the runtime subagents sequentially across multiple turns instead of in a single concurrent batch — defeats parallelism.
- Mid-loop canonical-memory writes — defeats Model C governance windows.
- Spec-phase skills spawning subagents via the Task tool — adds latency without rigor; Triggers 1/2/3 with the human are the adversary at spec phase.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24, refreshed
2026-04-25 — see `.vibeflow/decisions.md` "Three runtime subagents
only") — concrete artifact paths for each role:

- **Generator** → `agents/generator.md` (runtime subagent; memory
  scope: `task`; tools: read project files + host code; write
  `.yoke/progress.md` + `.yoke/contracts.md`).
- **Validator** → `agents/validator.md` (runtime subagent; memory
  scope: `task`; runs `hooks/verify-acceptance.sh`; emits structured
  JSON verdicts; co-writes `.yoke/contracts.md`).
- **Orchestrator** → `agents/orchestrator.md` (runtime subagent;
  three modes — consult, monitor, canonize; memory scope: `task` +
  canonical substrate; tools: `lib/canonical-memory/*.sh`,
  `lib/ralph-loop/escalate.sh`).
- **Spec-phase Generator persona** → `skills/discover/SKILL.md`,
  `skills/tech-spec/SKILL.md` (inline, no subagent).
- **Spec-phase Validator persona** →
  `skills/acceptance-contract/SKILL.md` (inline, no subagent).

The Generator/Validator/Orchestrator distinction is materialized as
**three subagent files**, instantiated only at runtime
(decision 2026-04-25 — Three runtime subagents only; supersedes
2026-04-24 — Five subagents).
