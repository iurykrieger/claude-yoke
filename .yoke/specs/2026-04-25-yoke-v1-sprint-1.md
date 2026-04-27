# Spec: Yoke v1 — Sprint 1 — Plugin scaffolding + bootstrap

> Generated via /vibeflow:gen-spec on 2026-04-24
> PRD: `.vibeflow/prds/yoke-v1.md`
> Plugin version target: 0.1.0

## Objective

Ship an installable Claude Code plugin with a working `/yoke:bootstrap`
that prepares a host project to use Yoke (creates `.yoke/`, points at or
creates the canonical-memory repo, validates dependencies).

## Context

No code exists yet. This sprint surfaces packaging, skill format, and
platform-integration risks early — before any complex skill logic depends
on them. Layout follows `vibeflow-claude` and `claude-bedrock` exactly,
which are the two reference plugins Claude Code already validates.

## Definition of Done

1. `/plugin marketplace add iurykrieger/yoke` recognizes the marketplace
   and `/plugin install yoke@yoke-marketplace` succeeds against a clean
   Claude Code install.
2. After install, `/yoke:` appears in the slash-command listing with all
   nine placeholder commands present (`bootstrap`, `discover`,
   `tech-spec`, `acceptance-contract`, `implement`, `canonize`,
   `drift-sense`, `ask`, `status`).
3. `/yoke:bootstrap` in a clean project creates a valid `.yoke/config.yaml`,
   asks about canonical-memory location, offers `gh repo create` if
   absent, and emits next-step guidance pointing at `/yoke:discover`.
4. `/yoke:bootstrap` is idempotent — running it twice does not corrupt state.
5. All scaffolded `SKILL.md` placeholders have valid frontmatter (`name`,
   `description`); plugin remains installable after the structure is added.
6. `docs/installation.md` and `docs/quickstart.md` are sufficient for an
   external reviewer to install and run `/yoke:bootstrap` without extra help.
7. **Craftsmanship gate:** repository structure matches `patterns/plugin-structure.md`
   exactly (including the eleven top-level entries and the directory
   tree under `skills/`, `agents/`, `hooks/`, `lib/`, `templates/`).

## Scope

- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`
- All directories from `patterns/plugin-structure.md` created with
  executable shell-script skeletons (`#!/bin/bash` + `exit 0`) and valid
  `SKILL.md` placeholders for the eight not-yet-implemented commands
- Real implementation of `skills/bootstrap/SKILL.md`
- Templates `templates/yoke-config.yaml` and `templates/project-claude-md.md`
- Docs: `installation.md`, `quickstart.md`, `architecture.md` (1-page
  summary of the manifesto), `canonical-memory-setup.md`
- Top-level: `README.md`, `CHANGELOG.md` (entry for 0.1.0), `CLAUDE.md`
  (instructions for Claude Code operating this plugin repo)

## Anti-scope

- Real implementation of `/yoke:discover`, `/yoke:tech-spec`, etc. — placeholders only.
- Subagent implementations — placeholder agent files only.
- Hook logic — `exit 0` shells only.
- Canonical-memory query/write logic — none.
- A `gh`-CLI degraded mode — bootstrap hard-fails with install guidance
  if `gh` is missing (PRD Open Question 5).

## Technical Decisions

- **Skill format** follows Claude Code's `SKILL.md` schema exactly as
  used by `vibeflow-claude` and `claude-bedrock`. Trade-off: pinning
  to today's schema; mitigation is Risk R6 monitoring.
- **`gh` CLI verification** during bootstrap: hard-fail with install
  instructions when missing. Trade-off: forces an upfront install on
  the user but keeps the rest of the framework's git-native protocol
  honest. Degraded mode deferred.
- **Canonical-memory repo creation**: `/yoke:bootstrap` either points
  at an existing repo or runs `gh repo create` to make a new one.
  Bootstrap leaves the repo empty — Sprint 5 (`/yoke:canonize`) is the
  first writer. Trade-off: a fresh user sees an empty `/yoke:ask` until
  Sprint 5 lights up; documented in `quickstart.md`.
- **bash 4+** for hooks; documented in `installation.md` (macOS users
  need Homebrew bash).

## Applicable Patterns

- `plugin-structure.md` — primary; the "Implementation Mapping" addendum
  applies directly.
- `memory-model.md` — `.yoke/` layout for working memory and the
  separate canonical-memory repo.
- `human-triggers.md` — `/yoke:bootstrap` interactive prompts use
  Trigger-1-style approval shape (clear question, explicit yes/no).

No new patterns introduced.

## Risks

- **R1 — subagent depth (sidestepped, but verify).** PRD chose
  Orchestrator-as-skill, so no subagent spawns another subagent.
  Sprint-1 spike must still confirm a *skill* can invoke a *subagent*
  via the Task tool against the current Claude Code version. **Mitigation:**
  spike on day 1 of Sprint 1 with a throwaway test plugin; if the Task
  tool flow doesn't work, escalate before continuing.
- **R6 — plugin marketplace format drift.** Sprint 1 IS the validation.
  **Mitigation:** mirror `vibeflow-claude/.claude-plugin/` and `claude-bedrock/.claude-plugin/`
  one-for-one; flag any divergence during install testing.
- **R7 — multi-step bootstrap UX.** Bootstrap touches `gh`, repo
  creation, `.yoke/` config, and a host `CLAUDE.md`. **Mitigation:** every
  step has a clear error message and a "what to do next" pointer; one
  external reviewer (anyone other than Iury) tests the bootstrap path
  before declaring DoD met.

## Dependencies

None. Sprint 1 is the foundation.
