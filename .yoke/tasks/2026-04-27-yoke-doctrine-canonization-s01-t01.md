---
task_id: 2026-04-27-yoke-doctrine-canonization-s01-t01
sprint: 1
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s01-t01 — Enumerate every `.vibeflow/` reference in framework code as a committed inventory artifact.

## Story

Sprint 4 cannot be partitioned without a concrete file list. Without an
authoritative inventory, every cutover task is open-ended, and the
zero-references invariant in sprint 5 has no baseline to verify
against. This task produces the inventory as a load-bearing,
committed artifact that pins every subsequent cutover task.

## Technical implementation

- Run `grep -rn --include='*.md' --include='*.sh' --include='*.yaml' --include='*.json' '.vibeflow/' skills/ agents/ hooks/ lib/ templates/` from the repo root and capture stdout. Both the literal directory token `.vibeflow/` and any narrower path like `.vibeflow/patterns/roles.md` match — use a fixed-string grep (`-F`) of the substring `.vibeflow/` to avoid regex escaping.
- Format the matches as one bullet per match: `- <relpath>:<line> — <excerpt>` where `<excerpt>` is the trimmed line content.
- Persist two outputs in this commit:
  1. **Inline inventory** in this task file's Validation section (versioned). The bulleted list is the canonical artifact future tasks read.
  2. **Runtime mirror** at `.yoke/runtime/vibeflow-inventory.txt` (gitignored). Same content; lets sprint-4 task code grep the inventory without parsing markdown.
- Group entries by directory (`skills/`, `agents/`, `hooks/`, `lib/`, `templates/`) and sort lexically within each group so re-runs produce a stable diff.
- Tooling: a one-shot bash block; no LLM judgment. Reusable as a sensor self-test fixture in sprint 5.

## Validation

- After capture, the Validation section of this task file contains a non-empty bulleted list under each of the five directory headings, each entry of the shape `<relpath>:<line> — <excerpt>`.
- Re-running the same `grep -rn` command produces a set equal to or a subset of the captured inventory (no new references introduced during the discovery phase). The Generator may run this re-grep as a self-check.
- The runtime mirror at `.yoke/runtime/vibeflow-inventory.txt` exists and matches the inline inventory line-for-line (modulo bullet formatting).
- Phase-3 BDD scenario for this task encodes: Given the framework surface as of the task's commit, When `grep -rn --include='*.md' --include='*.sh' --include='*.yaml' --include='*.json' '.vibeflow/' skills/ agents/ hooks/ lib/ templates/` runs, Then every match appears in this task file's Validation list.

### Inventory (captured 2026-04-27, cycle 1)

> Captured by the Generator subagent on 2026-04-27 from the framework
> surface (`skills/`, `agents/`, `hooks/`, `lib/`, `templates/`).
> 57 matches total. Mirrored verbatim (modulo bullet formatting) at
> `.yoke/runtime/vibeflow-inventory.txt`. Sprint 4 cutover tasks consume
> this list; the s05-t01 sensor self-test exercises a subset of these
> file:line tokens. `hooks/` carries no `.vibeflow/` references and
> therefore has no heading below.

#### skills/

- skills/acceptance-contract/SKILL.md:247 — - `.vibeflow/patterns/acceptance-contract.md`.
- skills/acceptance-contract/SKILL.md:248 — - `.vibeflow/patterns/sensors.md`.
- skills/acceptance-contract/SKILL.md:249 — - `.vibeflow/patterns/human-triggers.md` (Trigger 3).
- skills/ask/SKILL.md:278 — - `.vibeflow/patterns/memory-model.md` — the read-mediator role.
- skills/ask/SKILL.md:279 — - `.vibeflow/patterns/roles.md` — the canonical-memory read contract.
- skills/bootstrap/SKILL.md:37 — - `gh` CLI installed and authenticated. **Hard-fails with install instructions if missing** — no degraded mode (per `.vibeflow/decisions.md`).
- skills/discover/SKILL.md:253 — - `.vibeflow/patterns/phase-flow.md` (Phase 1).
- skills/discover/SKILL.md:254 — - `.vibeflow/patterns/roles.md` (Generator persona).
- skills/discover/SKILL.md:255 — - `.vibeflow/patterns/human-triggers.md` (Trigger 1).
- skills/drift-sense/SKILL.md:152 — - `.vibeflow/patterns/phase-flow.md` (Phase 6 section).
- skills/drift-sense/SKILL.md:153 — - `.vibeflow/patterns/model-c-governance.md` — deprecation propositions.
- skills/drift-sense/SKILL.md:154 — - `.vibeflow/patterns/sensors.md` — structured findings.
- skills/drift-sense/SKILL.md:155 — - `.vibeflow/patterns/memory-model.md` — frontmatter metadata.
- skills/drift-sense/SKILL.md:16 — `.vibeflow/patterns/phase-flow.md`, it operates on three targets and
- skills/implement/SKILL.md:280 — `.vibeflow/patterns/model-c-governance.md`, canonization decides
- skills/implement/SKILL.md:326 — see `.vibeflow/patterns/human-triggers.md`.
- skills/implement/SKILL.md:391 — - `.vibeflow/patterns/ralph-loop.md`.
- skills/implement/SKILL.md:392 — - `.vibeflow/patterns/roles.md`.
- skills/implement/SKILL.md:393 — - `.vibeflow/patterns/model-c-governance.md` — termination-time
- skills/preserve/SKILL.md:476 — only at loop termination per `.vibeflow/patterns/memory-model.md`.
- skills/preserve/SKILL.md:483 — - `.vibeflow/patterns/memory-model.md` — single write point invariant.
- skills/preserve/SKILL.md:484 — - `.vibeflow/patterns/model-c-governance.md` — impact classes + PR
- skills/status/SKILL.md:150 — pruning candidates per `.vibeflow/conventions.md` "Minimalist
- skills/status/SKILL.md:212 — - `.vibeflow/patterns/memory-model.md` — read-only role.
- skills/status/SKILL.md:213 — - `.vibeflow/patterns/phase-flow.md` — phase labels.
- skills/teach/SKILL.md:228 — - `.vibeflow/patterns/memory-model.md` — `/yoke:preserve` is the
- skills/teach/SKILL.md:230 — - `.vibeflow/patterns/model-c-governance.md` — impact-class routing
- skills/teach/SKILL.md:25 — > `.vibeflow/specs/bedrock-canonical-memory-port-part-5.md` anti-scope.
- skills/tech-spec/SKILL.md:108 — stack named in `.vibeflow/index.md` without major upgrades or
- skills/tech-spec/SKILL.md:121 — proposes feature X but the stack in `.vibeflow/index.md` is Y —
- skills/tech-spec/SKILL.md:357 — - `.vibeflow/patterns/phase-flow.md` (Phase 2).
- skills/tech-spec/SKILL.md:358 — - `.vibeflow/patterns/roles.md` (Generator persona).
- skills/tech-spec/SKILL.md:359 — - `.vibeflow/patterns/human-triggers.md` (Trigger 2; shared-menu rule).
- skills/tech-spec/SKILL.md:360 — - `.vibeflow/patterns/memory-model.md` (working-memory archive layout).
- skills/tech-spec/SKILL.md:361 — - `.vibeflow/conventions.md` ("blueprints wrapping agentic nodes",
- skills/tech-spec/SKILL.md:51 — `.vibeflow/conventions.md`:

#### agents/

- agents/generator.md:226 — - `.vibeflow/patterns/roles.md` — Generator role contract.
- agents/generator.md:227 — - `.vibeflow/patterns/ralph-loop.md` — loop structure, deterministic
- agents/generator.md:229 — - `.vibeflow/patterns/sensors.md` — structured-output expectations.
- agents/orchestrator.md:258 — - `.vibeflow/patterns/roles.md` — Orchestrator role contract.
- agents/orchestrator.md:259 — - `.vibeflow/patterns/model-c-governance.md` — write protocol;
- agents/orchestrator.md:261 — - `.vibeflow/patterns/memory-model.md` — canonical-memory format;
- agents/orchestrator.md:263 — - `.vibeflow/patterns/ralph-loop.md` — runtime loop semantics;
- agents/orchestrator.md:265 — - `.vibeflow/patterns/human-triggers.md` — Trigger-4 escalation.
- agents/orchestrator.md:77 — `.vibeflow/patterns/ralph-loop.md`: quality / standards /
- agents/semantic-judge.md:145 — - `.vibeflow/patterns/sensors.md` — calibration metadata,
- agents/semantic-judge.md:149 — - `.vibeflow/patterns/roles.md` — runtime subagents do not share
- agents/semantic-judge.md:151 — - `.vibeflow/conventions.md` — back-pressure (success non-silent
- agents/validator.md:171 — - `.vibeflow/patterns/roles.md` — Validator role contract.
- agents/validator.md:172 — - `.vibeflow/patterns/ralph-loop.md` — loop semantics, divergence
- agents/validator.md:174 — - `.vibeflow/patterns/sensors.md` — structured-output requirement,

#### lib/

- lib/ralph-loop/escalate.sh:21 — # .vibeflow/patterns/human-triggers.md.

#### templates/

- templates/approval-menu.md:243 — in `.vibeflow/patterns/human-triggers.md`.
- templates/approval-menu.md:6 — > **excluded** from this template — see `.vibeflow/patterns/human-triggers.md`
- templates/approval-menu.md:75 — `.vibeflow/patterns/human-triggers.md` ("shape is shared, semantics
- templates/task.md:22 — > `.vibeflow/patterns/memory-model.md`. `model` and `traceability`
- templates/task.md:35 — from `.vibeflow/patterns/` by name when applicable.>

## Acceptance criterion

`diff <(grep -rn --include='*.md' --include='*.sh' --include='*.yaml' --include='*.json' '.vibeflow/' skills/ agents/ hooks/ lib/ templates/ | sort) <(awk '/^## Validation/,/^## Acceptance criterion/' .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s01-t01.md | grep -oE '[a-z]+/[^ ]+:[0-9]+' | sort -u)` exits 0 — i.e., every live grep match has a corresponding inventory entry in this task file.