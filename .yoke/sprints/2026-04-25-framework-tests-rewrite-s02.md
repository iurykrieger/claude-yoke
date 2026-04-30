# Sprint 02 of 06: Framework tests rewrite

> Migrated from: # Spec: Framework tests rewrite — Part 2 (skills & agents surface)


> Generated via /vibeflow:gen-spec on 2026-04-25 from
> .vibeflow/prds/framework-tests-rewrite.md

## Objective

Add concept-shaped tests for the structural contract of every skill
in `skills/` and every runtime subagent in `agents/`.

## Context

`skills/` ships 14 skill folders today, each with a `SKILL.md`.
Frontmatter / allowed-tools / persona-inline rules are validated only
for 3 of them in the current sprint suite (discover, tech-spec, ask).
`agents/` ships exactly 3 runtime subagents whose write-authority
declarations are currently asserted across multiple sprint files.

This part collapses that coverage into one file per concept.

## Definition of Done

1. `tests/skills-surface.test.sh` exists. For every
   `skills/*/SKILL.md`, it asserts: (a) YAML frontmatter is
   well-formed (delimiters at line 1 and a matching `---`); (b) `name`
   is present and non-empty; (c) `description` is present and
   non-empty; (d) `allowed-tools` field is present.
2. For each spec-phase skill (`discover`, `tech-spec`,
   `acceptance-contract`), `skills-surface.test.sh` additionally
   asserts: (a) `Task` is NOT in `allowed-tools`; (b) the file embeds
   an inline persona section (matches
   `Generator persona|Validator persona|Your role .*persona`);
   (c) the binding human-trigger prompt is present (Trigger 1 in
   `discover`, Trigger 2 in `tech-spec`, Trigger 3 in
   `acceptance-contract`).
3. For `skills/ask/SKILL.md`, `skills-surface.test.sh` asserts:
   `allowed-tools` excludes both `Task` and `Write`; the SKILL
   declares the no-clone invariant
   (`grep -iE 'never .*(clone|pull|fetch)'`); declares no-fabrication;
   references `resolve-memory.sh`; caps entity reads at 15.
4. `tests/agents-surface.test.sh` exists. It asserts: (a) `agents/`
   contains exactly 3 `*.md` files; (b) the three are `generator.md`,
   `validator.md`, `orchestrator.md`; (c) `orchestrator.md` declares
   sole write authority over canonical memory; (d) `validator.md`
   references the structured-JSON-verdict format; (e)
   `generator.md` references `progress.md` per-cycle persistence.
5. `bash tests/skills-surface.test.sh` and
   `bash tests/agents-surface.test.sh` exit 0 against HEAD.
6. **Craftsmanship gate.**
   `grep -EIn 'sprint-[0-9]|Sprint [0-9]|Part [0-9]|v[0-9]+\.[0-9]+'
   tests/skills-surface.test.sh tests/agents-surface.test.sh`
   returns nothing.
7. Both files pass `bash -n` and (if available) `shellcheck`.

## Scope

- Create `tests/skills-surface.test.sh`.
- Create `tests/agents-surface.test.sh`.
- Both source `tests/lib/harness.sh` and call `harness::summary` at
  end-of-file.

## Anti-scope

- **No behavior tests.** Structural only — frontmatter,
  allowed-tools, persona presence, file presence. Behavior tests for
  `ask`, `preserve`, `bootstrap`, etc. live in Parts 3–4.
- **No host-project simulation.** No `mktemp -d`, no `.yoke/`
  scaffolding.
- **No coverage of `lib/` scripts** (Parts 3 and 4).
- **No CI changes** (Part 6).

## Technical Decisions

- **Loop over `skills/*/SKILL.md`.** Don't enumerate skills by name —
  every new skill gets the structural check for free.
- **Spec-phase skill list is hardcoded.** `discover`, `tech-spec`,
  `acceptance-contract` are the three Phase-1/2/3 skills per the
  manifesto and `patterns/plugin-structure.md`. Adding a new
  spec-phase skill requires a deliberate edit — a feature, not a
  bug.
- **`/yoke:ask` checks live here, not in canonical-memory tests.**
  This file validates the SKILL.md *surface* (frontmatter +
  declared invariants in prose). Behavior ("does it actually not
  clone?") lives in `tests/canonical-memory-read.test.sh` (Part 3).
- **Agent count is exact.** The manifesto pins three runtime
  subagents; growing them must be an explicit, ratified decision.

## Applicable Patterns

- `patterns/plugin-structure.md` — `agents/` is exactly 3 files;
  spec-phase persona-inline rule.
- `patterns/roles.md` — Generator/Validator/Orchestrator authority
  declarations (asserted via prose grep on the agent .md files).
- `conventions.md` Don'ts — "Do not allow any agent to read
  canonical memory directly"; "Do not allow any agent except the
  Orchestrator to write to canonical memory".

## Risks

- **A new skill is added but the spec-phase list is not updated.**
  The structural loop still covers it; the spec-phase subset stays
  focused. Failure (if any) is loud and localized.
- **Persona regex breaks on heading rename.** Keep the regex broad
  (`Generator persona|Validator persona|Your role .*persona`); fix
  is a one-line edit.

## Dependencies

- `.vibeflow/specs/framework-tests-rewrite-part-1.md`
