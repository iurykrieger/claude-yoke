---
tags: [plugin, repo-structure, claude-code, distribution, packaging, manifest]
modules: []
applies_to: [plugin-manifest, skills, agents, hooks, templates, lib, marketplace]
confidence: validated
---
# Pattern: Plugin Repository Structure

<!-- vibeflow:auto:start -->
## What
Yoke ships as a single Claude Code plugin. The repo is organized so
that every manifesto component (agents, skills, hooks, templates,
helper scripts, docs) lives in a known top-level directory. The
structure follows the conventions of `vibeflow-claude` and
`claude-bedrock` — same layout, same file formats, same
`/plugin install` mechanics.

## Where
The whole repository. The plan calls this the **target final**
structure; not every directory is populated in every sprint, but the
layout is fixed from Sprint 1 onward (skeletons in place by Sprint 1
Task 1.2).

## The Pattern

```
yoke/
├── .claude-plugin/
│   ├── plugin.json                   # plugin manifest
│   └── marketplace.json              # marketplace distribution metadata
│
├── skills/                           # one folder per skill
│   ├── discover/SKILL.md             # /yoke:discover — Phase 1 (Generator persona inline)
│   ├── tech-spec/SKILL.md            # /yoke:tech-spec — Phase 2 (Generator persona inline)
│   ├── acceptance-contract/SKILL.md  # /yoke:acceptance-contract — Phase 3 (Validator persona inline)
│   ├── implement/SKILL.md            # /yoke:implement — Phase 4 (spawns 3 subagents in parallel)
│   ├── canonize/SKILL.md             # /yoke:canonize — manual escape hatch
│   ├── drift-sense/SKILL.md          # /yoke:drift-sense — Phase 6
│   ├── ask/SKILL.md                  # /yoke:ask — thin canonical-memory query
│   ├── bootstrap/SKILL.md            # /yoke:bootstrap — initial setup
│   └── status/SKILL.md               # /yoke:status — current task state
│
├── agents/                           # three runtime subagents
│   ├── generator.md                  # runtime — code generation
│   ├── validator.md                  # runtime — sensor execution + structured JSON verdicts
│   └── orchestrator.md               # runtime — consult + monitor + canonize (sole canonical-memory writer)
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
│   │   ├── query.sh                  # progressive-disclosure query (called by /yoke:ask + Orchestrator consult)
│   │   ├── propose-write.sh          # opens PR on canonical repo (called by Orchestrator canonize only)
│   │   ├── canonization-criteria.sh  # five-criterion cascade
│   │   └── graph.sh                  # graph operations (depends_on, supersedes)
│   ├── ralph-loop/
│   │   ├── orchestrate.sh            # preflight + check-contradiction
│   │   └── escalate.sh               # human escalation (Trigger 4)
│   └── sensors/
│       ├── discover-from-claude-md.sh   # parses host CLAUDE.md
│       └── run-sensors.sh
│
├── docs/                             # plugin docs (NOT the manifesto)
│   ├── installation.md
│   ├── quickstart.md
│   ├── architecture.md               # 1-page summary of the manifesto
│   ├── canonical-memory-setup.md
│   ├── lineage.md
│   ├── scheduling-strategy.md
│   └── troubleshooting.md
│
├── examples/
│   └── greenfield-payment-service/
│
├── tests/
│   ├── plugin-install.test.sh
│   ├── skills-format.test.sh
│   └── smoke/
│       └── sprint-N.test.sh
│
├── CHANGELOG.md
├── CLAUDE.md                         # instructions for Claude Code operating this repo
├── README.md
└── LICENSE
```

### Manifesto component → artifact mapping

| Manifesto component | Plugin artifact | Type |
| :--- | :--- | :--- |
| Generator role (Section 11) | `agents/generator.md` (runtime subagent) + Generator persona inline in `skills/discover/SKILL.md` and `skills/tech-spec/SKILL.md` | subagent + skills |
| Validator role (Section 12) | `agents/validator.md` (runtime subagent) + Validator persona inline in `skills/acceptance-contract/SKILL.md` | subagent + skill |
| Orchestrator role (Section 13) | `agents/orchestrator.md` (runtime subagent — three modes: consult, monitor, canonize) | subagent |
| Phase 1 — Discovery | `skills/discover/SKILL.md` | skill |
| Phase 2 — Tech Spec | `skills/tech-spec/SKILL.md` | skill |
| Phase 3 — Acceptance Contract | `skills/acceptance-contract/SKILL.md` | skill |
| Phase 4 — Runtime (parallel-spawn ralph loop) | `skills/implement/SKILL.md` + `lib/ralph-loop/` + hooks + 3 runtime subagents | skill + scripts + subagents |
| Phase 5 — Canonization (auto, at loop termination) | Orchestrator subagent's canonize mode (invoked from `/yoke:implement` termination handoff) + `lib/canonical-memory/` | subagent + scripts |
| Phase 5 — Canonization (manual escape hatch) | `skills/canonize/SKILL.md` (spawns Orchestrator subagent in canonize mode) | skill |
| Phase 6 — Drift sensing | `skills/drift-sense/SKILL.md` + GitHub Actions schedule | skill + cron |
| Mediated canonical query — spec phases (13.1) | `skills/ask/SKILL.md` + `lib/canonical-memory/query.sh` | skill + script |
| Mediated canonical query — runtime (13.1) | Orchestrator subagent in consult mode + `lib/canonical-memory/query.sh` | subagent + script |
| Model C governance (Section 10) | logic in `agents/orchestrator.md` (canonize mode) + `lib/canonical-memory/propose-write.sh` | subagent + script |
| Working memory (14.1) | `.yoke/` in project repo | convention |
| Canonical memory (14.2) | separate git repo, created by `/yoke:bootstrap` | external repo |
| Sprint contracts (15.3) | `.yoke/contracts.md` | working-memory file |
| Hard bounds (15.4) | `hooks/check-hard-bounds.sh` + `lib/ralph-loop/orchestrate.sh` | hook + script |
| Computational sensors (15.1) | discovered by `lib/sensors/discover-from-claude-md.sh` | script |
| Human triggers (Section 9) | pause points in skills + Trigger-4 escalation packet | operational convention |
| Acceptance Contract binding (8.3) | enforced by `hooks/verify-acceptance.sh` | hook |
| Rippability metadata (16.8) | `templates/canonical-entry-frontmatter.yaml` | template |
| Progressive disclosure (Section 6) | `lib/canonical-memory/query.sh` | script |
| Embedded upstream skills (5.1) | forks inside `skills/`, evolving autonomously | embedded skills |

## Rules
- Skills follow Claude Code's `SKILL.md` frontmatter schema (same as `vibeflow-claude` and `claude-bedrock`).
- Subagent files in `agents/` are full prompt definitions: persona, behaviors, memory scope, allowed tools, restrictions.
- `agents/` contains exactly three files (runtime subagents only): `generator.md`, `validator.md`, `orchestrator.md`.
- Spec-phase personas (Generator, Validator) are embedded **inline** in their respective skills, not as separate subagents.
- Hooks in `hooks/` are bash 4+ scripts that exit 0 on success and non-zero on failure. A hook failure stops the ralph loop — they are deterministic critical nodes.
- `lib/` holds helper scripts that skills and agents invoke. Nothing in `lib/` is a skill or a hook; nothing in `lib/` is user-facing.
- `templates/` holds artifact skeletons consumed by skills. They are not agent prompts.
- `.yoke/` (working memory) lives in the **host project repo**, not in this plugin repo.
- The canonical-memory repo is **external** and created by `/yoke:bootstrap`. It is not a submodule of this plugin.
- `docs/` documents the **plugin**, not the framework. The framework manifesto (`yoke.md`) is referenced, not duplicated.

## Examples from this codebase
The structure above is realized as of v1.1.0 (refactor recorded in
`.vibeflow/decisions.md` "Three runtime subagents only", 2026-04-25).
v1.0 had five subagent files in `agents/`; v1.1 reduced to three.
Subsequent sprints continue to fill in the layout.

<!-- vibeflow:auto:end -->

## Anti-patterns
- Putting agents inside `skills/` (or vice versa) — they have different formats and different lifecycles.
- Storing working memory inside this plugin repo — it belongs in the host project's `.yoke/` directory.
- Treating `lib/` scripts as user-facing commands — they are internal helpers; only `skills/` exposes commands.
- Using the same repo for canonical memory and the plugin — collapses two different blast radii into one.
- Coupling Yoke versions to specific Vibeflow / Bedrock upstream tags — those skills are embedded at creation time and evolve internally.
- Letting `docs/` drift into duplicating the manifesto — `docs/architecture.md` is a 1-page summary, not a re-write.
- Re-introducing spec-phase Generator/Validator subagent files in `agents/` — they were eliminated in v1.1 because Triggers 1/2/3 with the human are the adversary at spec phase. The runtime adversariality lives in the runtime subagents only.
