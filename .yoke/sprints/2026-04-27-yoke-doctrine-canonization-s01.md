---
task_id: 2026-04-27-yoke-doctrine-canonization-s01
sprint: 1
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-yoke-doctrine-canonization.md#sprint-1
Migrated-from: [.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s01-t01.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s01-t02.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s01-t03.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s01-t04.md]
---

# Sprint 01: Foundations + slice (proof-of-concept)

## Sprint objective

A single end-to-end migration path is proved on one of each artifact type, the framework-surface inventory is committed as a load-bearing input, and the vault carries the project and actor entities that will hold every subsequent backlink.

## Sprint DoD

- 2026-04-27-yoke-doctrine-canonization-s01-t01: `diff <(grep -rn --include='*.md' --include='*.sh' --include='*.yaml' --include='*.json' '.vibeflow/' skills/ agents/ hooks/ lib/ templates/ | sort) <(awk '/^## Validation/,/^## Acceptance criterion/' .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s01-t01.md | grep -oE '[a-z]+/[^ ]+:[0-9]+' | sort -u)` exits 0 — i.e., every live grep match has a corresponding inventory entry in this task file.
- 2026-04-27-yoke-doctrine-canonization-s01-t02: Both `<iury-brain-checkout>/projects/claude-yoke.md` and `<iury-brain-checkout>/actors/yoke.md` exist with all required frontmatter keys present, AND both `/yoke:ask` sample queries above return entity hits whose responses contain the new file paths verbatim.
- 2026-04-27-yoke-doctrine-canonization-s01-t03: The four canonical-memory slice entities exist in `iury-brain`'s checkout AND the two working-memory slice files exist in `.yoke/specs/` and `.yoke/prds/`, AND running the six pre-defined `/yoke:ask` round-trip queries (committed in this task file's Validation section as a script) produces six non-empty responses each containing the corresponding entity's filename verbatim.
- 2026-04-27-yoke-doctrine-canonization-s01-t04: `grep -cF '.vibeflow/' <chosen-file>` returns 0 AND the file's first 10 lines (frontmatter region for skills, intro region for agents) parse without YAML / markdown errors AND this task file's Validation section contains the rewrite-pattern key as a committed artifact for sprint 4's bulk cutover.

## Tasks

### Task 2026-04-27-yoke-doctrine-canonization-s01-t01

**Story:**

Sprint 4 cannot be partitioned without a concrete file list. Without an
authoritative inventory, every cutover task is open-ended, and the
zero-references invariant in sprint 5 has no baseline to verify
against. This task produces the inventory as a load-bearing,
committed artifact that pins every subsequent cutover task.

**Technical implementation:**

- Run `grep -rn --include='*.md' --include='*.sh' --include='*.yaml' --include='*.json' '.vibeflow/' skills/ agents/ hooks/ lib/ templates/` from the repo root and capture stdout. Both the literal directory token `.vibeflow/` and any narrower path like `.vibeflow/patterns/roles.md` match — use a fixed-string grep (`-F`) of the substring `.vibeflow/` to avoid regex escaping.
- Format the matches as one bullet per match: `- <relpath>:<line> — <excerpt>` where `<excerpt>` is the trimmed line content.
- Persist two outputs in this commit:
  1. **Inline inventory** in this task file's Validation section (versioned). The bulleted list is the canonical artifact future tasks read.
  2. **Runtime mirror** at `.yoke/runtime/vibeflow-inventory.txt` (gitignored). Same content; lets sprint-4 task code grep the inventory without parsing markdown.
- Group entries by directory (`skills/`, `agents/`, `hooks/`, `lib/`, `templates/`) and sort lexically within each group so re-runs produce a stable diff.
- Tooling: a one-shot bash block; no LLM judgment. Reusable as a sensor self-test fixture in sprint 5.

**Validation:**

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

**Acceptance criterion:**

`diff <(grep -rn --include='*.md' --include='*.sh' --include='*.yaml' --include='*.json' '.vibeflow/' skills/ agents/ hooks/ lib/ templates/ | sort) <(awk '/^## Validation/,/^## Acceptance criterion/' .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s01-t01.md | grep -oE '[a-z]+/[^ ]+:[0-9]+' | sort -u)` exits 0 — i.e., every live grep match has a corresponding inventory entry in this task file.

### Task 2026-04-27-yoke-doctrine-canonization-s01-t02

**Story:**

The vault needs a project entity and an actor entity to hold backlinks
from every doctrine entity created in subsequent sprints. Without
these scaffolds, doctrine entities have no backlink target, and
`/yoke:ask` queries scoped to the Yoke project return zero results.
The two entities are the foundation every later sprint depends on.

**Technical implementation:**

- Locate the registered checkout via `bash lib/canonical-memory/registry.sh path-of iury-brain` (returns `/Users/iury.krieger/Workspace/iurykrieger/iury-brain`).
- Write `projects/claude-yoke.md` in the checkout. Frontmatter: `kind: project`, `tags: [yoke-framework]`, `status: active`, `repository: https://github.com/iurykrieger/yoke`, `version: 1.1.0`, `created: 2026-04-27`, `last_validated: 2026-04-27`. Body sections: a Status section (current sprint, deployment target), an Architecture section (link to the manifesto entity once migrated, summary of the three-runtime-subagent shape), and an empty `## Doctrine entities` section that subsequent migration tasks append to.
- Write `actors/yoke.md` similarly. Frontmatter: `kind: actor`, `tags: [yoke-framework]`, `status: active`, `project: claude-yoke`, `kind_detail: framework`, `created: 2026-04-27`, `last_validated: 2026-04-27`. Body: a Persona section (Yoke as a development framework with three runtime subagents), a Capabilities section, and a Backlinks section listing the role concepts (`yoke-pattern-roles` referenced once it is migrated).
- Open a canonical-memory PR via `/yoke:preserve` carrying both files. Model C classification: medium-impact (vault scaffolding); auto-merge after veto window.
- Update Yoke's local `iury-brain` checkout: `git pull` the merged PR before sprint-1 task 3 begins ingesting doctrine entities.

**Validation:**

- Both files exist at `<checkout>/projects/claude-yoke.md` and `<checkout>/actors/yoke.md`.
- Every required frontmatter key is present and non-empty (deterministic key check via a yaml-frontmatter parser, no LLM judgment).
- `/yoke:ask "what is the claude-yoke project?"` returns a hit citing `projects/claude-yoke.md` with at least one body excerpt visible in the response.
- `/yoke:ask "describe the yoke actor"` returns a hit citing `actors/yoke.md`.
- The PR opened via `/yoke:preserve` is merged into `iurykrieger/brain` (URL captured in this task's `traceability` frontmatter field at completion).

**Acceptance criterion:**

Both `<iury-brain-checkout>/projects/claude-yoke.md` and `<iury-brain-checkout>/actors/yoke.md` exist with all required frontmatter keys present, AND both `/yoke:ask` sample queries above return entity hits whose responses contain the new file paths verbatim.

### Task 2026-04-27-yoke-doctrine-canonization-s01-t03

**Story:**

Before bulk migration in sprints 2 and 3, prove the migration shape
works for one of each artifact type. If `/yoke:teach` chokes on a
particular shape (e.g., the decision-log split, or a frontmatter the
upstream Bedrock skill doesn't expect), we discover it on six
ingestions, not eighty. The slice is the recursive-failure-of-dogfood
canary from the PRD's risk list.

**Technical implementation:**

- Pick the slice (one of each kind):
  - **Pattern:** `.vibeflow/patterns/roles.md` (most-referenced pattern in framework code, per the s01-t01 inventory; highest-value to migrate first).
  - **Decision:** the most-recent decision in `.vibeflow/decisions.md` (today: "2026-04-25 — Generator subagent persona = Senior Developer").
  - **Policy:** `.vibeflow/conventions.md` (single entity for the whole conventions doc, `kind: policy`).
  - **Audit:** the most-recent file in `.vibeflow/audits/` (alphabetic last after sort).
  - **Spec:** `.vibeflow/specs/yoke-v1-sprint-1.md` (oldest spec; lowest risk for slug truncation).
  - **PRD:** `.vibeflow/prds/yoke-v1.md` (the seed PRD).
- For pattern, decision, policy, audit: invoke `/yoke:teach` with the source path plus a target-shape spec (kind, tags, destination path, ratification date preserved verbatim from source). Each call writes one entity into the vault checkout.
- For spec and PRD: derive a slug from the file's first-commit date (`git log --diff-filter=A --follow --format=%cs --reverse -- <path> | head -1`); `git mv` the file to `.yoke/specs/<slug>.md` or `.yoke/prds/<slug>.md`. Confirm the slug matches `wm_validate_slug`.
- After each migration, perform a `/yoke:ask` round-trip (one query per migrated entity, picked to hit a substring unique to that entity).
- Append each migrated entity's path to the `## Doctrine entities` section of `projects/claude-yoke.md` (created in s01-t02). Open a Model C PR for that single change.

**Validation:**

- Six entities exist at expected paths: `concepts/yoke-pattern-roles.md`, `concepts/yoke-decision-2026-04-25-generator-subagent-persona-senior-developer.md` (or equivalent slug), `concepts/yoke-conventions.md`, one `discussions/yoke-audit-*.md` file, one `.yoke/specs/<slug>.md`, one `.yoke/prds/<slug>.md`.
- Each entity's frontmatter contract is satisfied (every required key present and non-empty).
- Six `/yoke:ask` round-trip queries return non-empty hits whose responses include the entity's filename or a substring lifted verbatim from the entity's body.
- `projects/claude-yoke.md` now lists six bullets under `## Doctrine entities` (the four canonical-memory entities; specs/PRDs are working memory and do NOT backlink to the project entity).

**Acceptance criterion:**

The four canonical-memory slice entities exist in `iury-brain`'s checkout AND the two working-memory slice files exist in `.yoke/specs/` and `.yoke/prds/`, AND running the six pre-defined `/yoke:ask` round-trip queries (committed in this task file's Validation section as a script) produces six non-empty responses each containing the corresponding entity's filename verbatim.

### Task 2026-04-27-yoke-doctrine-canonization-s01-t04

**Story:**

Before bulk cutover in sprint 4, prove the rewrite path on a single
file. The chosen file should have multiple `.vibeflow/` references so
the rewrite covers both `/yoke:ask` invocations (for doctrine) and
working-memory paths (for project history). If `/yoke:ask`
invocation patterns don't compose cleanly inside skill prose, we
catch it once, not 50 times.

**Technical implementation:**

- Read `.yoke/runtime/vibeflow-inventory.txt` (produced by s01-t01) and pick the file with the highest count of distinct `.vibeflow/` references inside `skills/` or `agents/`. Tie-break alphabetically. The chosen path is recorded in this task's `traceability` field at completion.
- For each `.vibeflow/` reference in the chosen file:
  - **Doctrine reference** (matches `.vibeflow/patterns/*` or `.vibeflow/decisions.md` or `.vibeflow/conventions.md`): rewrite to a `/yoke:ask` invocation phrase. The exact phrasing pattern is documented inline in this task's Validation section so sprint-4 tasks reuse it verbatim.
  - **Project-history reference** (matches `.vibeflow/specs/*` or `.vibeflow/prds/*`): rewrite to the corresponding `.yoke/specs/<slug>.md` or `.yoke/prds/<slug>.md` path. For specs/PRDs not yet migrated, hold the rewrite until s01-t03's slice migration covers them, OR pick a different file. The slice contains one spec and one PRD — the chosen file should reference at most those two project-history items.
  - **Index reference** (`.vibeflow/index.md`): rewrite to a `/yoke:ask` invocation about the project entity (`projects/claude-yoke.md`).
- Preserve all surrounding prose verbatim. The rewrite is a pure string substitution at the reference; nothing else in the file changes.
- The rewrite-pattern decisions made here (exact `/yoke:ask` phrasing, query verb form, citation style) become the convention sprint 4's bulk cutover follows.

**Validation:**

- `grep -F '.vibeflow/' <chosen-file>` returns 0 matches.
- The file's YAML frontmatter (if a skill) parses as valid YAML; if a Markdown agent file, the frontmatter is unchanged.
- Diff the file against its pre-cutover version: only `.vibeflow/`-bearing lines are altered, plus minimal prose adjustments to maintain sentence structure.
- A documented "rewrite-pattern key" is committed in this task file's Validation section, listing each reference category and its replacement template (e.g., `.vibeflow/patterns/X.md → /yoke:ask "describe the X pattern (concepts/yoke-pattern-X)"`).
- The chosen file is hand-read end-to-end after the rewrite to verify internal consistency.

**Acceptance criterion:**

`grep -cF '.vibeflow/' <chosen-file>` returns 0 AND the file's first 10 lines (frontmatter region for skills, intro region for agents) parse without YAML / markdown errors AND this task file's Validation section contains the rewrite-pattern key as a committed artifact for sprint 4's bulk cutover.

## Functional acceptance criteria

- (criterion IDs to be resolved from .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md when that AC artifact migrates to the new shape; left empty for now since the doctrine task already shipped)

## Sensors

- (post-shipped sprint; sensors recorded in audit reports)
