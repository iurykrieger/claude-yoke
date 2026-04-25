---
tags: [plugin, repo-structure, claude-code, distribution, packaging, manifest]
modules: []
applies_to: [plugin-manifest, skills, agents, hooks, templates, lib, marketplace]
confidence: validated
---
# Pattern: Plugin Repository Structure

<!-- vibeflow:auto:start -->
## What
Yoke ships as a single Claude Code plugin. The repo is organized so that
every manifesto component (agents, skills, hooks, templates, helper scripts,
docs) lives in a known top-level directory. The structure follows the
conventions of `vibeflow-claude` and `claude-bedrock` — same layout, same
file formats, same `/plugin install` mechanics.

## Where
The whole repository. The plan calls this the **target final** structure;
not every directory is populated in every sprint, but the layout is fixed
from Sprint 1 onward (skeletons in place by Sprint 1 Task 1.2).

## The Pattern

```
yoke/
├── .claude-plugin/
│   ├── plugin.json                   # plugin manifest
│   └── marketplace.json              # marketplace distribution metadata
│
├── skills/                           # one folder per skill
│   ├── discover/SKILL.md             # /yoke:discover — Phase 1
│   ├── tech-spec/SKILL.md            # /yoke:tech-spec — Phase 2
│   ├── acceptance-contract/SKILL.md  # /yoke:acceptance-contract — Phase 3
│   ├── implement/SKILL.md            # /yoke:implement — Phase 4
│   ├── canonize/SKILL.md             # /yoke:canonize — Phase 5
│   ├── drift-sense/SKILL.md          # /yoke:drift-sense — Phase 6
│   ├── ask/SKILL.md                  # /yoke:ask — mediated canonical-memory query
│   ├── bootstrap/SKILL.md            # /yoke:bootstrap — initial setup
│   └── status/SKILL.md               # /yoke:status — current task state
│
├── agents/                           # five subagents
│   ├── generator.md                  # PRD / Tech Spec drafter
│   ├── validator.md                  # Acceptance Contract drafter
│   ├── orchestrator.md               # mediator + coordinator + canonizer
│   ├── implementation.md             # runtime instance of Generator
│   └── validation.md                 # runtime instance of Validator
│
├── hooks/                            # deterministic checkpoints
│   ├── pre-implementation.sh         # state check before Phase 4
│   ├── post-iteration.sh             # persists progress.md and contracts.md
│   ├── verify-acceptance.sh          # runs Acceptance Contract sensors + fixtures
│   └── check-hard-bounds.sh          # cycle / timeout / budget enforcement
│
├── templates/                        # artifact templates
│   ├── prd.md
│   ├── tech-spec.md
│   ├── acceptance-contract.md
│   ├── progress.md
│   ├── contracts.md
│   └── canonical-entry-frontmatter.yaml
│
├── lib/                              # internal helper scripts
│   ├── canonical-memory/
│   │   ├── query.sh                  # progressive-disclosure query
│   │   ├── propose-write.sh          # opens PR on canonical repo
│   │   └── graph.sh                  # graph operations (depends_on, supersedes)
│   ├── ralph-loop/
│   │   ├── orchestrate.sh            # coordinates Implementation ↔ Validation
│   │   └── escalate.sh               # human escalation (Trigger 4)
│   └── sensors/
│       ├── discover-from-claude-md.sh   # parses host CLAUDE.md
│       └── run-sensors.sh
│
├── docs/                             # plugin docs (NOT the manifesto)
│   ├── installation.md
│   ├── quickstart.md
│   ├── architecture.md               # 1-page summary of the manifesto
│   └── canonical-memory-setup.md
│
├── examples/
│   └── greenfield-payment-service/
│
├── tests/
│   ├── plugin-install.test.sh
│   └── skills-format.test.sh
│
├── CHANGELOG.md
├── CLAUDE.md                         # instructions for Claude Code operating this repo
├── README.md
└── LICENSE
```

### Manifesto component → artifact mapping

| Manifesto component | Plugin artifact | Type |
| :--- | :--- | :--- |
| Generator (Section 11) | `agents/generator.md` | subagent |
| Validator (Section 12) | `agents/validator.md` | subagent |
| Orchestrator (Section 13) | `agents/orchestrator.md` | subagent |
| Implementation Agent (11.2) | `agents/implementation.md` | subagent |
| Validation Agent (12.4) | `agents/validation.md` | subagent |
| Phase 1 — Discovery | `skills/discover/SKILL.md` | skill |
| Phase 2 — Tech Spec | `skills/tech-spec/SKILL.md` | skill |
| Phase 3 — Acceptance Contract | `skills/acceptance-contract/SKILL.md` | skill |
| Phase 4 — Runtime | `skills/implement/SKILL.md` + `lib/ralph-loop/` + hooks | skill + scripts |
| Phase 5 — Canonization | `skills/canonize/SKILL.md` + `lib/canonical-memory/` | skill + scripts |
| Phase 6 — Drift sensing | `skills/drift-sense/SKILL.md` + GitHub Actions schedule | skill + cron |
| Mediated canonical query (13.1) | `skills/ask/SKILL.md` + `lib/canonical-memory/query.sh` | skill + script |
| Model C governance (Section 10) | logic in `agents/orchestrator.md` + `lib/canonical-memory/propose-write.sh` | subagent + script |
| Working memory (14.1) | `.yoke/` in project repo | convention |
| Canonical memory (14.2) | separate git repo, created by `/yoke:bootstrap` | external repo |
| Sprint contracts (15.3) | `.yoke/contracts.md` | working-memory file |
| Hard bounds (15.4) | `hooks/check-hard-bounds.sh` + `lib/ralph-loop/orchestrate.sh` | hook + script |
| Computational sensors (15.1) | discovered by `lib/sensors/discover-from-claude-md.sh` | script |
| Human triggers (Section 9) | pause points in skills + agents | operational convention |
| Acceptance Contract binding (8.3) | enforced by `hooks/verify-acceptance.sh` | hook |
| Rippability metadata (16.8) | `templates/canonical-entry-frontmatter.yaml` | template |
| Progressive disclosure (Section 6) | `lib/canonical-memory/query.sh` | script |
| Embedded upstream skills (5.1) | forks inside `skills/`, evolving autonomously | embedded skills |

## Rules
- Skills follow Claude Code's `SKILL.md` frontmatter schema (same as `vibeflow-claude` and `claude-bedrock`).
- Subagent files in `agents/` are full prompt definitions: persona, behaviors, memory scope, allowed tools, restrictions.
- Hooks in `hooks/` are bash 4+ scripts that exit 0 on success and non-zero on failure. A hook failure stops the ralph loop — they are deterministic critical nodes.
- `lib/` holds helper scripts that skills and agents invoke. Nothing in `lib/` is a skill or a hook; nothing in `lib/` is user-facing.
- `templates/` holds artifact skeletons consumed by skills. They are not agent prompts.
- `.yoke/` (working memory) lives in the **host project repo**, not in this plugin repo.
- The canonical-memory repo is **external** and created by `/yoke:bootstrap`. It is not a submodule of this plugin.
- `docs/` documents the **plugin**, not the framework. The framework manifesto (`yoke.md`) is referenced, not duplicated.

## Examples from this codebase
> Repository is empty. The structure above will materialize incrementally:
> Sprint 1 Task 1.2 creates all directories with placeholders. Subsequent
> sprints fill them in. Sprint 1 Task 1.1 already validates `plugin.json`
> against the Claude Code schema (same schema as `vibeflow-claude`).

<!-- vibeflow:auto:end -->

## Anti-patterns
- Putting agents inside `skills/` (or vice versa) — they have different formats and different lifecycles.
- Storing working memory inside this plugin repo — it belongs in the host project's `.yoke/` directory.
- Treating `lib/` scripts as user-facing commands — they are internal helpers; only `skills/` exposes commands.
- Using the same repo for canonical memory and the plugin — collapses two different blast radii into one.
- Coupling Yoke versions to specific Vibeflow / Bedrock upstream tags — those skills are embedded at creation time and evolve internally.
- Letting `docs/` drift into duplicating the manifesto — `docs/architecture.md` is a 1-page summary, not a re-write.
