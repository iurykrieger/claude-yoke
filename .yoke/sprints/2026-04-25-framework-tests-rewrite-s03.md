# Sprint 03 of 06: Framework tests rewrite

> Migrated from: # Spec: Framework tests rewrite — Part 3 (memory tests)


> Generated via /vibeflow:gen-spec on 2026-04-25 from
> .vibeflow/prds/framework-tests-rewrite.md

## Objective

Add concept-shaped tests for working-memory layout invariants and the
canonical-memory read + write protocols.

## Context

Today's coverage is split across `tests/smoke/folder-isolation.test.sh`
(working memory paths), `tests/smoke/ask-no-clone.test.sh` (canonical
read no-clone), and `tests/smoke/preserve-model-c.test.sh` (canonical
write Model C routing) — plus duplicate assertions inside
`sprint-N.test.sh`. This part collapses that coverage into three
concept-shaped files; sprint files are still in place but are
deleted in Part 6.

Patterns governing this part:
- `patterns/memory-model.md` — working vs. canonical separation.
- `patterns/model-c-governance.md` — impact classes; auto-merge rules.
- `conventions.md` Don'ts — direct canonical reads forbidden;
  Orchestrator is the sole writer; no flat-path strings outside
  `paths.sh`.

## Definition of Done

1. `tests/working-memory.test.sh` simulates an end-to-end flow in
   `mktemp -d`, sourcing `lib/working-memory/paths.sh`. It asserts:
   (a) every file written under `.yoke/` lands in an allowed location
   (`config.yaml`, `.gitignore`, `.current`, `prds/<slug>.md`,
   `tech-specs/<slug>.md`, `acceptance-contracts/<slug>.md`,
   `contracts/<slug>.md`, `runtime/*`); (b) no flat
   `.yoke/<file>.md` for `prd|tech-spec|acceptance-contract|contracts|progress`
   exists; (c) static grep over `skills/`, `lib/`, `hooks/` finds no
   flat-path strings outside `paths.sh`; (d) `.gitignore` content is
   exactly `.current\nruntime/`; (e) `.current` size equals the slug
   byte length (no trailing newline).
2. `tests/canonical-memory-read.test.sh` scaffolds a memory via
   `lib/canonical-memory/scaffold-memory.sh`, registers it via
   `registry.sh add`, calls `resolve-memory.sh --memory <name>`
   twice, and asserts: (a) the registered repo's `git reflog` count
   is unchanged across both resolutions; (b) both resolutions return
   the same path; (c) `resolve-memory.sh` source contains no
   `git clone|pull|fetch`. The test cleans up registry entries it
   creates via `trap`.
3. `tests/canonical-memory-write.test.sh` asserts source-level
   invariants (no execution of real PR opening): (a)
   `lib/canonical-memory/propose-write.sh` does not exist;
   (b) `skills/canonize/` does not exist; (c)
   `skills/preserve/SKILL.md` declares the four impact classes
   (`low`, `medium`, `high`, `regulatory`); (d) high never
   auto-merges; (e) regulatory routes via CODEOWNERS;
   (f) `canonization-criteria.sh` is referenced; (g) the three git
   strategies (`commit-push`, `commit-push-pr`, `commit-only`) are
   honored; (h) bidirectional linking is declared; (i) all five
   rippability fields (`ratified_at`, `model_calibrated_against`,
   `last_validated`, `traceability`, `impact_level`) are present;
   (j) `agents/orchestrator.md` invokes `/yoke:preserve`;
   (k) `grep -rEln 'git -C "?\$MEMORY_PATH"? commit'` over
   `agents/ skills/ lib/ tests/`, excluding `skills/preserve/`,
   returns empty.
4. `bash tests/working-memory.test.sh`,
   `bash tests/canonical-memory-read.test.sh`,
   `bash tests/canonical-memory-write.test.sh` each exit 0 against
   HEAD.
5. **Craftsmanship gate.**
   `grep -EIn 'sprint-[0-9]|Sprint [0-9]|Part [0-9]|v[0-9]+\.[0-9]+'
   tests/working-memory.test.sh tests/canonical-memory-read.test.sh
   tests/canonical-memory-write.test.sh` returns nothing.
6. All three files pass `bash -n` and (if available) `shellcheck`.

## Scope

- Create `tests/working-memory.test.sh`.
- Create `tests/canonical-memory-read.test.sh`.
- Create `tests/canonical-memory-write.test.sh`.
- Each sources `tests/lib/harness.sh` and calls `harness::summary`.
- Each isolates with `mktemp -d` + `trap` cleanup.

## Anti-scope

- **No real PR opening.** `canonical-memory-write.test.sh` inspects
  source only. End-to-end PR runs happen in host projects.
- **No assertions about manifesto wording.** Only assertions about
  SKILL.md / agent.md / `lib/*.sh` source.
- **No coverage of `bootstrap` (Part 4)** — the registration step
  exercised here uses `registry.sh` directly, not the bootstrap
  skill.
- **No CI changes** (Part 6).

## Technical Decisions

- **`working-memory.test.sh` exercises the path helper directly,
  not the skill.** Skills are markdown — exercising prose belongs to
  spec phase, not tests.
- **`git reflog` count as no-clone sensor.** Already validated in
  `tests/smoke/ask-no-clone.test.sh`. If `resolve-memory.sh` ever
  shells out to a git read that mutates reflog, this test correctly
  fails.
- **Registry isolation via `YOKE_PLUGIN_DIR` env override.** Pattern
  borrowed from `ask-no-clone.test.sh`: tests can scope their
  registry writes to the worktree without polluting global state. If
  the registry doesn't honor `YOKE_PLUGIN_DIR`, the test falls back
  to backing up and restoring `memories.json` via `trap`.
- **Source-level write-protocol checks instead of e2e.** Opening a
  real PR against a canonical-memory repo per-CI-run is too slow and
  requires creds; declared invariants in `skills/preserve/SKILL.md`
  are the right unit-of-test.

## Applicable Patterns

- `patterns/memory-model.md` — two-tier memory; lifetime.
- `patterns/model-c-governance.md` — impact classes; auto-merge
  rules; CODEOWNERS for regulatory.
- `conventions.md` Don'ts — direct reads forbidden; only Orchestrator
  writes; no flat-path strings outside `paths.sh`.

## Risks

- **`resolve-memory.sh` interface drift.** If the lib renames flags
  (`--memory` → `--name`), the test breaks. Mitigation: pin to the
  current interface; rename is a deliberate signal that a downstream
  test must update.
- **`scaffold-memory.sh` may require git config.** CI environment
  needs `user.name` / `user.email`. Mitigation: set them in the test
  before scaffolding (`git config --local`), per the existing
  pattern.
- **`canonical-memory-write.test.sh` overlaps `skills-surface`
  assertions** for `skills/preserve/SKILL.md`. Decision: surface
  test owns frontmatter; this part owns Model C semantic claims.

## Dependencies

- `.vibeflow/specs/framework-tests-rewrite-part-1.md`
