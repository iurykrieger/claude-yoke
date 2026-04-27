---
task_id: 2026-04-27-sprint-as-cycle-s04-t06
sprint: 4
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-4
---

# Task 2026-04-27-sprint-as-cycle-s04-t06 — Draft the Phase 5 canonization packet at `.yoke/runtime/.preserve-packet.md`: a new `concepts/yoke-pattern-sprint-runtime-bundle.md` entity body, a `refined_by:` link to add to `concepts/yoke-pattern-memory-model.md`, and a new `concepts/yoke-decision-2026-04-27-sprint-id-zero-pad-supersedes-task-id-zero-p.md` decision that supersedes `yoke-decision-2026-04-25-task-ids-zero-pad-to-2-digits-filename-only`.

## Story

The doctrine writes happen at Phase 5 (`/yoke:preserve`, post-loop), governed by Model C. This task drafts the packet that `/yoke:preserve` consumes: three canonical-memory writes, each bundled with the rippability frontmatter required by `concepts/yoke-pattern-memory-model`. The packet itself is working memory (gitignored under `.yoke/runtime/`) — the actual canonical-memory PR opens after the loop terminates.

## Technical implementation

- Create `.yoke/runtime/.preserve-packet.md` (gitignored, runtime artifact).
- Section 1: **New entity** at `concepts/yoke-pattern-sprint-runtime-bundle.md` in canonical memory.
  - Frontmatter:
    ```yaml
    ---
    type: concept
    name: "yoke-pattern-sprint-runtime-bundle"
    aliases: ["sprint-runtime-bundle pattern", "Sprint runtime bundle"]
    category: "pattern"
    description: "Sprint files are self-contained ralph-cycle runtime bundles. One sprint = one ralph cycle (with up to 8 cycle attempts). Sprint files reference AC criteria and sensors by ID; they never inline."
    status: "active"
    ratified: 2026-04-27
    last_validated: 2026-04-27
    traceability: ".yoke/prds/2026-04-27-sprint-as-cycle.md"
    project: "claude-yoke"
    refines: ["yoke-pattern-memory-model"]
    tags: [type/concept, kind/pattern, yoke-framework, status/active, domain/runtime]
    ---
    ```
  - Body: explanation of the pattern. Sections: What (sprint = ralph-cycle atom), Where (`.yoke/sprints/<slug>-s<NN>.md`), The Pattern (frontmatter + 5 H2 sections), Rules (reference-by-ID; serial walk; per-sprint hard bound; phase artifacts stay one-file-per-task), Examples, Anti-patterns, Implementation Mapping. Cite the PRD as the source.
- Section 2: **Refinement** of `concepts/yoke-pattern-memory-model.md`.
  - Diff to add `refined_by: [yoke-pattern-sprint-runtime-bundle]` to the frontmatter.
  - Diff to update the "post-tech-spec-task-split" working-memory layout block to show `.yoke/sprints/<slug>-s<NN>.md` (not `.yoke/tasks/<slug>-s<NN>-t<MM>.md`).
  - Body diff to replace the per-task-file clause: "Sprint index → one-line stories; per-task file → full Story / Technical implementation / Validation / Acceptance criterion" with: "Sprint index → cross-sprint architecture; per-sprint runtime bundle → full Story / Technical implementation / Validation / Acceptance criterion per task as anchors inside the bundle. See `concepts/yoke-pattern-sprint-runtime-bundle` for the runtime-bundle shape."
- Section 3: **New decision** at `concepts/yoke-decision-2026-04-27-sprint-id-zero-pad-supersedes-task-id-zero-p.md`.
  - Frontmatter with `supersedes: [yoke-decision-2026-04-25-task-ids-zero-pad-to-2-digits-filename-only]`, `superseded_by: []`, `status: active`, `ratified: 2026-04-27`, etc.
  - Body: "Sprint IDs zero-pad to 2 digits (filename only). Task IDs become anchors inside sprint files (no filename concern). The original decision is superseded because the per-task-file shape it parameterized has been retired by the sprint-as-cycle PRD."
- Section 4: **Supersession** of `yoke-decision-2026-04-25-task-ids-zero-pad-to-2-digits-filename-only`.
  - Diff to add `superseded_by: [yoke-decision-2026-04-27-sprint-id-zero-pad-supersedes-task-id-zero-p]` to the existing decision's frontmatter.
  - Diff to update its `status: active` → `status: superseded`.
- Each section in the packet is structured as a JSON-friendly block so `/yoke:preserve` Phase 3 (Model C cascade) can route each diff to the correct impact class. Cite `concepts/yoke-pattern-model-c-governance` for the routing rules.

## Validation

- File exists at `.yoke/runtime/.preserve-packet.md` and is gitignored (`git check-ignore .yoke/runtime/.preserve-packet.md` exits 0).
- Section count smoke: the packet contains exactly 4 H1/H2-level sections (one new entity, one memory-model refinement, one new decision, one supersession diff).
- Frontmatter completeness smoke: the new entity body's frontmatter has all 5 rippability fields per `concepts/yoke-pattern-memory-model` (`ratified`, `last_validated`, `traceability`, etc.) plus the relationship fields (`refines`, optionally `supersedes`).
- Cross-reference smoke: every supersession backlink referenced in the packet's section 4 names an entity that exists in the registered canonical memory (verifiable by `/yoke:ask "does yoke-decision-2026-04-25-task-ids-zero-pad-to-2-digits-filename-only exist?"`).
- Phase-5-readiness smoke: `/yoke:preserve --dry-run` (if available) on the packet produces a non-error diff summary; otherwise this assertion is deferred to runtime invocation.

## Acceptance criterion

`test -f .yoke/runtime/.preserve-packet.md && git check-ignore .yoke/runtime/.preserve-packet.md && grep -c "^## " .yoke/runtime/.preserve-packet.md | grep -qE "^\s*[4-9]\s*$"` exits 0 (file exists, gitignored, has at least 4 H2 sections).
