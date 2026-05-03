# Migrating from claude-yoke v3.x to v4.0.0

> Audience: host projects pinned on `claude-yoke@3.x` upgrading to
> `@4.0.0`. The cutover is a **breaking change**: paths, the Phase 3
> skill verb, the binding-artifact name, and the binding-artifact body
> shape all change. Plan a single coordinated upgrade.

## What changed

The v4.0.0 release renames and reshapes Yoke's Phase 3 binding artifact
from "Acceptance Contract" to "Acceptance Criteria", aligning the
artifact with standard QA discipline. The flat BDD-scenarios-with-
sensor-list shape is replaced by a layered hierarchy:

```
User Stories → Definition of Done → Acceptance Criteria → Sensor pool
```

The skill that produces the artifact (`/yoke:acceptance-criteria`,
formerly `/yoke:acceptance-contract`) is rewritten as an interactive
Senior-QA grill: it resumes the PRD + Tech Spec back to the user
(≤ 25 lines), runs a 1–5 round lettered-options dialogue scoped to base
quality gates, and refuses to render Trigger 3 if any pool sensor
fails to resolve. Sensor selection per Acceptance Criterion is a
runtime council decision; the binding artifact lists the pool
unclassified, and Sr QA / Sr Staff pick which pool members gate which
criterion at Phase 4.

The 17 historical files under `.yoke/acceptance-contracts/` are
**not migrated** — they remain frozen on disk for traceability, and
sensor scripts that walk the legacy directory continue to recognize
both paths.

Source PRD: `.yoke/prds/2026-05-03-acceptance-criteria-refactor.md`.

## Renames

| Surface                    | v3.x                                            | v4.0.0                                          |
|----------------------------|-------------------------------------------------|-------------------------------------------------|
| Working-memory directory   | `.yoke/acceptance-contracts/`                   | `.yoke/acceptance-criteria/`                    |
| Phase 3 skill verb         | `/yoke:acceptance-contract`                     | `/yoke:acceptance-criteria`                     |
| Plugin skill directory     | `skills/acceptance-contract/`                   | `skills/acceptance-criteria/`                   |
| Plugin template file       | `templates/acceptance-contract.md`              | `templates/acceptance-criteria.md`              |
| Path helper                | `wm_acceptance_contract_path`                   | `wm_acceptance_criteria_path`                   |
| Plugin version             | `3.0.0`                                         | `4.0.0`                                         |

## New artifact shape

The Acceptance Criteria document carries the following structure:

```markdown
# Acceptance Criteria — <task name>

> PRD: <path>
> Tech Spec: <path>
> Status: ratified
> Ratified by: <user>
> Ratified at: <iso8601>

> **Binding statement (Trigger 3).** Approving this document
> operationally defines "done" as "passes every criterion below" …

## User Stories

### US-001 — <title>

As a <role>, I want <capability>, so that <benefit>.

#### Definition of Done

- [ ] <binary completion item>
- [ ] <binary completion item>

#### Acceptance Criteria

- **AC-001-1:** <observable QA condition>
- **AC-001-2:** <observable QA condition>

### US-002 — <title>

…

## Functional Requirements

- **FR-1:** <cross-cutting requirement>

## Sensor pool

- <sensor-id>
- <sensor-id>

## Open Questions

None.
```

## Sensor pool — no classification at authoring time

The `## Sensor pool` section is a flat bullet list of sensor IDs. The
binding artifact does NOT classify pool members as mandatory /
complementary / optional at authoring time — that classification is a
runtime council decision. At Phase 4, Sr QA and Sr Staff each pick the
subset of pool members that gates each Acceptance Criterion they
evaluate, recording the selection (and rationale) in their per-cycle
slice file under `.yoke/runtime/cycles/<N>/<persona>.md`.

This shifts the policy decision from author-time to runtime, where the
council has both the cycle's evidence and the criterion's observable
condition in scope. Authoring-time tags would lock the policy before
the runtime evidence exists.

## Behavioral changes

- **Interactive grill.** `/yoke:acceptance-criteria` runs an
  interactive 1–5 round dialogue with lettered options
  (`A. … B. … C. … D. Other:`), mirroring the shape of
  `/yoke:discover` and `/yoke:tech-spec`. The skill never
  auto-generates the artifact silently from PRD + Tech Spec alone.
- **PRD + Tech Spec resume.** Before the first grill question fires,
  the skill emits a structured ≤ 25-line summary of the upstream
  artifacts (problem, goals, non-goals, sprint titles + DoD
  checklists) so the user is grounded before deciding quality gates.
- **Quick-Round fast-track.** When PRD goals + Tech Spec sprints
  already imply unambiguous US/DoD/AC shape, the skill proposes a
  full draft in one shot and converges in a single confirmation
  round — mitigation against grill fatigue on small features.
- **Sensor-pool fail-closed gate.** Before rendering Trigger 3, the
  skill invokes `lib/sensors/resolve-pool.sh` against the in-progress
  draft. If any pool entry fails to resolve to
  `.yoke/sensors/<id>.md`, the skill aborts with a `wm:`-prefixed
  message naming each unresolvable ID; the menu is not rendered.
- **DoD vs AC enforced.** The runtime council evaluates DoD before
  AC for each User Story — DoD passes are a precondition for AC
  evaluation. The arbiter classifies DoD-level disagreements and
  AC-level disagreements as direct contradictions; sensor-selection
  disagreements (different pool subsets selected by different
  personas) are importance disagreements.
- **User stories migrate out of the PRD.** `templates/prd.md` no
  longer carries a `## User Stories` section; `skills/discover/SKILL.md`
  no longer instructs the dialogue to enumerate `US-###` and
  instead points users at `/yoke:acceptance-criteria` as the User
  Story owner. PRDs continue to carry `## Functional Requirements`
  for cross-cutting system-level requirements.

## What is NOT migrated

- **Historical Acceptance Contract files** under
  `.yoke/acceptance-contracts/` are NOT migrated. They remain frozen
  on disk for traceability. The `.yoke/acceptance-contracts/`
  directory is preserved indefinitely; tools that walk binding
  artifacts (e.g., `lib/sensors/ack-sensors.sh`) recognize both the
  new and the legacy directory.
- **The legacy `/yoke:acceptance-contract` verb is removed.** No
  delegation, no shim. Invocations of the old verb fail with
  "skill not found". Update any custom workflow / hook / prompt
  that references it.
- **`wm_acceptance_contract_path` is deleted from
  `lib/working-memory/paths.sh`.** Bash scripts that source the
  helper file and call the legacy function fail at the
  command-not-found boundary. Update any custom sensor or hook
  that references it.

## Upgrade steps

1. **Update plugin pin.** Change your `claude-yoke` dependency from
   `3.x` to `4.0.0` (or floating). Restart Claude Code to reload the
   plugin manifest.
2. **Re-bootstrap the host project's CLAUDE.md (optional).** Run
   `/yoke:bootstrap --refresh-claude-md` if you want the new
   project-claude-md template applied. Manual edits to your existing
   `CLAUDE.md` are preserved by the bootstrap merge logic.
3. **Audit custom scripts.** Search your repository for the legacy
   surfaces:
   ```bash
   grep -RIn 'wm_acceptance_contract_path\|/yoke:acceptance-contract\|\.yoke/acceptance-contracts/' .
   ```
   - Function-call sites: replace with `wm_acceptance_criteria_path`.
   - Skill-verb references: replace with `/yoke:acceptance-criteria`.
   - Path literals: replace with `.yoke/acceptance-criteria/` for
     any code that resolves the *active task's* binding artifact.
     Keep historical references (e.g., audit-log entries that cite
     a specific frozen file) verbatim.
4. **Re-run any in-flight Phase 3.** If your project has a draft (not
   yet ratified) Acceptance Contract under `.yoke/acceptance-contracts/`,
   re-run `/yoke:acceptance-criteria` from scratch. The new skill
   will produce the v4.0.0-shaped artifact at the new path; abandon
   the legacy draft (it remains on disk as a historical artifact).
5. **Verify the cutover.** Run the orphan-ref sensor:
   ```bash
   bash tests/smoke/orphan-acceptance-contract-refs.test.sh
   ```
   It exits 0 only when no unaccounted `acceptance-contract`
   references remain in active code paths (allowlist: this migration
   doc and the project `CLAUDE.md`'s "Migration history" block).
