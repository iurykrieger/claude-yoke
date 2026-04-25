# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/) and this
project adheres to [Semantic Versioning](https://semver.org/).

## [1.1.0] — 2026-04-25 — Runtime-only agents

Architectural refactor of the agent topology. v1.0 had five subagent
files (Generator + Validator at spec phase, Implementation Agent +
Validation Agent at runtime, Orchestrator demoted to a skill via the
PRD-v0 amendment). v1.1 collapses this to **three runtime subagents
only**, embeds spec-phase personas inline in skills, and promotes
the Orchestrator back to a proper subagent.

> **Clean break.** v1.0 had no active host-project users, so v1.1 is
> a clean break with no migration path. Already-bootstrapped `.yoke/`
> directories continue to work — the changes live in the plugin's
> `agents/` and `skills/`, not in user repos.

### Changed

- **`agents/` reduced from 5 files to 3** (runtime subagents only):
  - `generator.md` — runtime code generation (renamed from `implementation.md` via `git mv` to preserve history)
  - `validator.md` — runtime sensor execution + structured JSON verdicts (renamed from `validation.md`)
  - `orchestrator.md` — promoted back to a subagent; three modes (consult / monitor / canonize)
- **Spec-phase skills now drive their own dialogue** (no Task spawn):
  - `/yoke:discover` — Generator persona embedded inline; `allowed-tools` no longer includes `Task`
  - `/yoke:tech-spec` — Generator persona embedded inline
  - `/yoke:acceptance-contract` — Validator persona embedded inline; sensor discovery preserved
- **`/yoke:implement` spawns 3 runtime subagents in parallel per cycle** — single concurrent Task batch in one assistant turn (previously sequential). At loop termination, issues a final Orchestrator-only Task call with `mode=canonize` for the canonization handoff.
- **`/yoke:ask` is a thin direct-call skill** — invokes `lib/canonical-memory/query.sh` directly and writes its own trace to `.yoke/query-trace.md`. The "Orchestrator skill in mediator mode" concept is retired.
- **`/yoke:canonize` is repositioned as a manual escape hatch** — primary canonization runs automatically inside `/yoke:implement` at loop termination via the Orchestrator subagent. The skill exists for manual re-runs (after model upgrades, or after a failed auto-canonize).
- Pattern docs and decision log updated to match: `roles.md`, `ralph-loop.md`, `memory-model.md`, `plugin-structure.md`, `phase-flow.md`, `index.md`, `conventions.md`, `model-c-governance.md`, `sensors.md`, `acceptance-contract.md`. Four new decision entries dated 2026-04-25 in `.vibeflow/decisions.md`.
- Manifesto (`yoke.md`) §10, §11, §12, §13, §15, §16, §19 updated to reflect the new topology and the *consult live, canonize on termination* canonization stance.
- `docs/architecture.md` refreshed with the new 3-subagent topology and an updated diagram.
- All sprint smoke tests (`tests/smoke/sprint-{2,3,4,5}.test.sh`) updated to assert the new topology; sprint-1 and sprints 6-8 untouched.

### Removed

- `skills/orchestrator/SKILL.md` — Orchestrator runtime / canonize / mediator modes moved to `agents/orchestrator.md` (subagent) and `skills/ask/SKILL.md` (thin skill).
- Spec-phase `agents/generator.md` and `agents/validator.md` (the v1.0 spec-phase variants) — personas now inline in their respective skills.

### Architectural invariants (new in v1.1)

- *Skills deliberate; subagents adapt.* — Skills handle deterministic dialogue; subagents handle runtime adaptation. Codified in `.vibeflow/decisions.md`.
- *Consult live, canonize on termination.* — Canonical memory is read freely during the runtime loop (Orchestrator consult mode) but written only at loop termination. Mid-loop writes are forbidden.

## [1.0.0] — 2026-04-25 — First stable release

Sprint 8 of an 8-sprint plan. **Yoke v1.0 is feature-complete and
ready for marketplace publication.** See
`.vibeflow/specs/yoke-v1-sprint-8.md` and
`.vibeflow/audits/yoke-v1-sprint-8-audit.md`.

### What's new in 1.0.0

- `examples/greenfield-payment-service/` — full end-to-end reference example. Worked artifacts (`prd.md`, `tech-spec.md`, ratified `acceptance-contract.md`) for a Node.js / TypeScript payment-reversal service with 7 BDD scenarios, 6 functional requirements, PCI-DSS + LGPD policy citations, and 6 computational sensors discoverable from a worked `CLAUDE.md`. Replaces the Sprint-1 `.gitkeep`.
- `docs/lineage.md` — per-skill provenance mapping. Vibeflow (`pe-menezes/vibeflow` 1.10.0, forked Sprint 2) → `skills/discover/SKILL.md`, `skills/tech-spec/SKILL.md`. Bedrock (`iurykrieger/claude-bedrock` 1.2.1, forked Sprint 5) → `lib/canonical-memory/{query,graph}.sh`. Yoke-native artifacts identified explicitly. Honesty statement included.
- `docs/troubleshooting.md` — 30+ common issues + recovery paths covering installation, all six phases, and generic operational questions.
- `.github/workflows/ci.yml` — runs **every sprint smoke** on every PR + push to main. JSON manifest validation, SKILL.md frontmatter check, shell-parse audit, all 7 sprint smokes (Sprint-4 protected with external `timeout 600` per Risk R5). CI badge in `README.md`.
- `tests/smoke/sprint-8.test.sh` — 50+ deterministic checks: example completeness (BDD scenario count, FR count, status: approved/ratified, sensor extraction from example CLAUDE.md), README finalization (CI badge, install command, links), all 7 docs/*.md present, lineage doc has both upstream URLs + per-skill mapping + honesty statement, troubleshooting has all 6 phase sections, CI workflow runs all sprint smokes including the timeout-600 wrap on Sprint 4, marketplace artifacts at v1.0.0, full plugin-structure conformance audit, full-audit-gate regression (all 7 prior sprint smokes still PASS).
- `README.md` — finalized: v1.0.0 status section listing all six manifesto phases as operational, CI badge, contributing instructions, complete project-documents inventory.

### Manifesto-pillar status (v1.0.0)

| Pillar | Status | Sprint(s) |
| :--- | :--- | :--- |
| Binding spec — PRD + Tech Spec + Acceptance Contract | ✅ operational | 1, 2, 3 |
| Adversarial loop — Implementation/Validation Agents with hard bounds | ✅ operational | 4, 6 |
| Governed memory — Orchestrator skill, full Model C (4 impact classes) | ✅ operational | 5, 6 |
| Five distinct human triggers (non-coalescable schemas) | ✅ operational | 6 |
| Progressive disclosure — subgraph queries | ✅ operational | 6 |
| Phase 6 — continuous drift sensing | ✅ operational | 7 |
| Rippability metadata + traceability | ✅ operational | 5, 6 |

### Known limitations / planned for v1.1+

- **Adversarial canonical-memory audit** (manifesto §17 anticipated extension).
- **Post-deploy production-signal observation** (manifesto §17).
- **Inferential drift-sensing detector** (semantic obsolescence; v1.0 is metadata-only).
- **Yoke-on-Yoke** (recursive bootstrap; v1.0 was built manually per `.vibeflow/decisions.md`).
- **Per-task-class hard-bound profiles** (PRD Open Question 4; v1.0 ships single profile).
- **Local cron / daemon backends for drift sensing** (documented in `docs/scheduling-strategy.md`; v1.0 ships only GitHub Actions backend).

### Outstanding `/vibeflow:teach` queue (rolled into v1.0 docs as audit pitfalls)

Audits across Sprints 1–7 accumulated 11 pitfall items for `/vibeflow:teach`
canonization. The most urgent — **deferred-anti-scope smoke convention**
— fired in 5 consecutive sprint audits and is documented inline in each
sprint smoke. Other queued items live in
`.vibeflow/audits/yoke-v1-sprint-{N}-audit.md` files for future ratification.

### Manual verification for first-time users

Before announcing v1.0.0 publicly:

1. `/plugin marketplace add iurykrieger/yoke` against a clean Claude Code install.
2. `/plugin install yoke@yoke-marketplace` — confirm v1.0.0.
3. `/yoke:bootstrap` in a fresh repo.
4. Walk an external reviewer through `examples/greenfield-payment-service/` using only `docs/quickstart.md`.
5. Trigger `.github/workflows/yoke-drift-sense.yml` manually in a real GitHub repo with a populated canonical-memory store.

## [0.7.0] — 2026-04-25

Sprint 7 of an 8-sprint plan. **Phase 6 drift sensing now operational.**
See `.vibeflow/specs/yoke-v1-sprint-7.md` and
`.vibeflow/audits/yoke-v1-sprint-7-audit.md`.

### Added
- `/yoke:drift-sense` (`skills/drift-sense/SKILL.md`) — real implementation. Three modes (`--target codebase`, `--target canonical-memory`, `--target traces`, plus convenience `--target all`). Findings emitted as structured YAML. Runs in Orchestrator Canonizer-mode context (mode declaration `[orchestrator:canonizer drift-sense]`). Drift-sense propositions go through Model C — no auto-merging.
- `lib/canonical-memory/staleness-check.sh` — pure-metadata detector for canonical-memory drift. Three finding kinds: `stale` (last_validated > max-days), `model-drift` (calibrated against ≠ current model), `contradiction` (contradicts_with: live entry in repo). Configurable via `.yoke/config.yaml` `overrides.drift_sense.staleness_max_days` (default 30).
- `lib/canonical-memory/trace-analyzer.sh` — trace-mode detector. Counts contract `topic:` occurrences across one or more `.yoke/contracts.md` files; flags topics that recur ≥ N times (default 3, configurable via `overrides.drift_sense.recurrence_min`) without a corresponding canonical-memory entry. Works against multiple `--trace-dir` for cross-task analysis.
- `.github/workflows/yoke-drift-sense.yml` — daily cron at 06:00 UTC + manual `workflow_dispatch`. Idempotent: SHA-256 signature comparison at `.yoke/.drift-sense-last-signature` ensures unchanged findings don't open new issues. Posts findings as a GitHub issue with the `yoke-drift-sense` label.
- `docs/scheduling-strategy.md` — records the GitHub Actions decision (rationale + trade-offs), credentials walkthrough (`GITHUB_TOKEN` permissions), issue label setup (`gh label create`), and three documented fallback backends (local cron / daemon / other CI providers — none implemented in v1.0 per anti-scope).
- `tests/smoke/sprint-7.test.sh` — 35+ deterministic checks: skill structure, all 3 modes documented, staleness-check across 4 synthetic frontmatter shapes (fresh / stale / model-drift / contradiction; verifies no false positives on the fresh entry), trace-analyzer across 4 synthetic contracts (recurrence detection + one-off skip + already-canonized skip), workflow YAML structure (cron + permissions + idempotency + script invocation + issue creation), scheduling-strategy doc requirements, anti-scope (no auto-merge, status skill placeholder), regression for Sprints 2–6.

### Notes
- Drift sensing is the only Yoke phase that runs **outside the per-task change lifecycle**. Findings feed Orchestrator Canonizer-mode propositions through Model C exactly like any other write — typically `medium`-impact deprecation entries with veto window.
- v0.7.0 implements only the GitHub-Actions backend. Local cron / daemon / other CI providers are documented in `docs/scheduling-strategy.md` as future-work fallbacks per Sprint-7 anti-scope.
- False-positive rate on the synthetic-injection smoke test: 0 % (target: <20 %). Pure metadata math is conservative by design — when in doubt, drift sensing should under-flag rather than create issue-tracker noise.
- After Sprint 7, only Sprint 8 (polish + example + marketplace publication) remains for v1.0.0.

## [0.6.0] — 2026-04-25

Sprint 6 of an 8-sprint plan. **Yoke is now minimally usable end-to-end
for small projects.** See `.vibeflow/specs/yoke-v1-sprint-6.md` and
`.vibeflow/audits/yoke-v1-sprint-6-audit.md`.

### Added
- `hooks/check-hard-bounds.sh` — real implementation. Enforces cycles_max (default 8), timeout_seconds (default 14400 = 4h), and token_budget (default 200000). Per-project overrides under `overrides.hard_bounds:` in `.yoke/config.yaml`. Reaching any bound invokes `escalate.sh` and exits 10 (loop pauses, never aborts silently).
- `lib/ralph-loop/escalate.sh` — real Trigger-4 packet emitter. Writes structured YAML to `.yoke/.trigger4-packet.yaml` and stdout: `trigger: 4`, reason (divergence | contract-conflict | hard-bound | infeasibility), divergence_category, full state (progress.md, contracts.md, latest snapshot, plus cycle/timeout/token state for hard-bound), unresolved_sprint_contract, escalation_to, decision_required.
- `lib/canonical-memory/graph.sh` — real subgraph traversal. Two subcommands: `list-edges <repo> <file>` extracts depends_on / supersedes / applies_to / contradicts_with edges from frontmatter; `subgraph <repo> <seed> --depth N` BFS-traverses up to N hops following all four edges.
- Full Model C in `lib/canonical-memory/propose-write.sh`:
  - **medium** impact → comment-announces veto window (default 24h, configurable via `overrides.model_c.veto_window_hours`); auto-merge after window
  - **high** impact → `auto-merge: never`; explicit human approval required
  - **regulatory** impact → `auto-merge: never`; verifies CODEOWNERS in canonical repo for Compliance routing; warns if missing
  - All four impact classes (low/medium/high/regulatory) accepted; unknown values still rejected with exit 4
- `tests/smoke/sprint-6.test.sh` — 35+ checks: hard-bound enforcement (no-state / cycles / timeout / per-project override), Trigger-4 packet structure (divergence + hard-bound packets, state inclusion), 5 distinct trigger schemas (pairwise diff), medium-impact veto window with override, high/regulatory paths, progressive-disclosure subgraph traversal (3-node graph + unrelated exclusion), performance (<2s on 100-entry synthetic memory), Orchestrator skill impact rules + docs.

### Changed
- `skills/orchestrator/SKILL.md` — added explicit "Impact classification rules" section with the 4-class table (regulatory / high / medium / low), keyword triggers per class, and PR-behavior column. Notes conservative classification (overlap with higher class wins).
- `skills/implement/SKILL.md` — termination paths now wire `escalate.sh` for divergence, contract-conflict, hard-bound, and infeasibility; documents the four divergence sub-categories from `patterns/ralph-loop.md` §15.6.
- `lib/canonical-memory/query.sh` — added `--subgraph-depth N` flag. When N ≥ 1, takes first grep match's file as seed and emits subgraph reachable via the four frontmatter edges. Caps at 10 entries to bound context.
- `docs/architecture.md` — added Model C table with all 4 impact classes, trigger keywords, PR behavior, and decision path.
- `docs/canonical-memory-setup.md` — added "CODEOWNERS for regulatory routing" subsection with recommended skeleton and `propose-write.sh`'s detection rule.

### Notes
- After Sprint 6, **all manifesto-core invariants are operational**: binding spec (Sprints 1–3), adversarial loop with hard bounds (Sprints 4 + 6), governed memory under full Model C (Sprints 5 + 6). PRD success-criteria DoD gate "hard bounds are respected" is now verifiable in code.
- Trigger-4 schema is non-coalescable with Triggers 1, 2, 3, 5. Smoke verifies all five emit distinct signatures.
- Sprint 7 ships Phase-6 drift sensing; Sprint 8 ships polish + marketplace publication.

## [0.5.0] — 2026-04-25

Sprint 5 of an 8-sprint plan. See `.vibeflow/specs/yoke-v1-sprint-5.md` and
`.vibeflow/audits/yoke-v1-sprint-5-audit.md`.

### Added
- `skills/orchestrator/SKILL.md` — Orchestrator skill with three explicit modes (Mediator / Runtime coordinator / Canonizer). Sole writer of canonical memory. Mode declarations (`[orchestrator:mediator|runtime-coordinator|canonizer]`) are written to `.yoke/query-trace.md` for audit and future canonization signal. Resolves PRD Open Question 1 with single-skill layout.
- `/yoke:canonize` (`skills/canonize/SKILL.md`) — Phase 5 real implementation. Reads completed-task working memory, applies canonization criteria, opens low-impact PRs via `propose-write.sh`. Lists medium/high candidates as DEFERRED (Sprint 6 path).
- `lib/canonical-memory/canonization-criteria.sh` — bash 4 + awk implementation of the five-criterion cascade. Reads `.yoke/contracts.md` per-block, applies non-contradiction filter (criterion 5), classifies impact via keyword heuristic (regulatory/high/medium/low), classifies kind (divergence-pattern / template-refinement / sensor-calibration / other). Emits structured YAML candidate list. Performance contract: <5s on 1000-block memory.
- `lib/canonical-memory/propose-write.sh` — low-impact PR path. Clones canonical-memory repo, creates branch `yoke-propose-<id>`, writes entry with mandatory rippability frontmatter, opens PR with `yoke-proposal` + `impact-low` labels, configures auto-merge after CI checks. Supports `--dry-run` for tests. Hard-rejects non-low-impact candidates with exit 4 (Sprint 6 territory).
- `tests/smoke/sprint-5.test.sh` — 30+ deterministic checks: Orchestrator skill structure, three mode declarations, canonization-criteria positive/negative/non-contradiction/performance, propose-write usage/impact/dry-run/labels, query.sh `--trace` flag writes structured trace entries, anti-scope (Sprint-6 territories), regression for Sprints 2/3/4.

### Changed
- `skills/ask/SKILL.md` — now declares Mediator mode, calls `query.sh --trace .yoke/query-trace.md --invoker "<skill-or-agent>"`. Bypass detection rule documented (trace absence is the signal).
- `lib/canonical-memory/query.sh` — added `--trace <path>` and `--invoker <name>` flags. Initializes `.yoke/query-trace.md` with header if absent. Writes YAML trace entry per query (timestamp, mode, query, subgraph_depth, matches, capped, invoker, optional notes).

### Removed
- `agents/orchestrator.md` — placeholder removed per PRD v0 amendment. The Orchestrator is a *skill* now (`skills/orchestrator/SKILL.md`); having both files would confuse maintainers and the placeholder's own header explicitly anticipated this Sprint-5 deletion.

### Notes
- Resolves **PRD v0 amendment** for the Orchestrator at the codebase level: the Orchestrator is now a skill that invokes the four agent subagents via the Task tool. Risk R1 (subagent depth) is fully sidestepped. Pattern docs (`.vibeflow/decisions.md`, `roles.md`, `plugin-structure.md`, `model-c-governance.md`) still need a `/vibeflow:teach` round to ratify the amendment textually.
- v0.5.0 ships only the **low-impact** Model C path. Medium-impact (veto window) and high-impact (synchronous ratification) paths land in Sprint 6.
- Tests use `--dry-run` to avoid PR creation against real repos. Real-flow validation requires `gh` authenticated against a test canonical-memory repo.

## [0.4.0] — 2026-04-25

Sprint 4 of an 8-sprint plan. See `.vibeflow/specs/yoke-v1-sprint-4.md` and
`.vibeflow/audits/yoke-v1-sprint-4-audit.md`.

### Added
- `agents/implementation.md` — full Implementation Agent runtime instance (memory scope `task`; persona, behaviors, restrictions per `.vibeflow/patterns/roles.md` and `ralph-loop.md`). Distinct from the Generator.
- `agents/validation.md` — full Validation Agent runtime instance. Emits structured JSON verdicts (`criterion` / `status` / `location` / `fix_instruction` / `sensor` / `evidence`). Distinct from the Validator.
- `/yoke:implement` (`skills/implement/SKILL.md`) — Phase 4 basic ralph loop, real implementation. Orchestrator-skill in runtime-coordinator mode; spawns subagents via the Task tool (PRD v0 amendment — no agent-spawning-agent). Pre-flight + cycle loop + contradiction check + persistence + stop check.
- `lib/ralph-loop/orchestrate.sh` — three deterministic subcommands: `preflight` (verifies pre-conditions; exit 3 / 4 / 0), `append-contract` (appends a YAML fragment to `.yoke/contracts.md`), `check-contradiction` (heuristic textual contradiction detection between sprint contracts and the Acceptance Contract; exit 10 on detection).
- `hooks/post-iteration.sh` — increments `.yoke/.cycle-counter` (read by Sprint-6's hard-bound check) and snapshots `verify-acceptance.sh` output to `.yoke/.snapshots/cycle-<N>.yaml`.
- `templates/progress.md` — real schema (Cycle N blocks with timestamp / next_step / files_touched / sensor_feedback_consumed / contract_consensus_reached / citing_criterion / notes).
- `templates/contracts.md` — real schema (Contract <id> blocks with id / topic / decision / rationale / timestamp / agents_involved / references / cycle).
- `tests/smoke/sprint-4.test.sh` — 30+ deterministic checks: subagent presence/distinctness/restrictions, skill format, three orchestrate.sh subcommands across full state matrix, post-iteration counter + snapshot, anti-scope (hard bounds / escalation / canonical-memory write all still skeletons; Orchestrator placeholder; canonize/drift-sense/status placeholders), Sprint-2 + Sprint-3 regression.

### Notes
- Sprint 4 is **pre-Sprint-6**: no hard-bound enforcement. Tests must wrap with external `timeout 600`. Sprint 6 ships hard bounds and the formal Trigger-4 escalation packet.
- The agentic parts of the loop (Implementation Agent ↔ Validation Agent dialogue via Claude Code's Task tool) require runtime to validate; this sprint ships the deterministic scaffolding around them.
- The PRD's v0 amendment (Orchestrator-as-skill) is exercised at the contract level by `/yoke:implement` invoking subagents via Task. Backporting the amendment to pattern docs (`.vibeflow/decisions.md`, `roles.md`, `plugin-structure.md`, `model-c-governance.md`) remains required before Sprint 5.

## [0.3.0] — 2026-04-25

Sprint 3 of an 8-sprint plan. See `.vibeflow/specs/yoke-v1-sprint-3.md` and
`.vibeflow/audits/yoke-v1-sprint-3-audit.md`.

### Added
- `agents/validator.md` — full Validator subagent definition (persona, behaviors, memory scope, allowed tools, restrictions per `.vibeflow/patterns/roles.md`). Functional objective opposite the Generator's: measurable rigor.
- `/yoke:acceptance-contract` (`skills/acceptance-contract/SKILL.md`) — Phase 3, real implementation. Aborts on missing/unapproved PRD or Tech Spec; pauses for Trigger-3 ratification with the binding statement printed verbatim.
- `lib/sensors/discover-from-claude-md.sh` — bash 4 parser that extracts the first backticked command from each bullet under `## Testing`, `## Linting`, `## Build` sections (case-insensitive). Emits structured YAML; falls back to a `notes:` entry when nothing is found so the Validator asks the user.
- `hooks/verify-acceptance.sh` — runs the computational sensors declared in `.yoke/acceptance-contract.md` and emits per-sensor results (`pass` / `fail` / `skip`) with command, exit code, output excerpt, and reason. Sensors whose binary is missing report `skip`, not `fail`.
- `templates/acceptance-contract.md` — manifesto-shape template: binding statement, BDD scenarios, FRs, applicable policies, sensor sections aligned with `verify-acceptance.sh`'s parser.
- `tests/smoke/sprint-3.test.sh` — extends Sprint 2's smoke with Validator subagent checks, sensor discovery against three CLAUDE.md states (missing / no sections / fully populated), `verify-acceptance.sh` against synthetic Acceptance Contract (pass/fail/skip cases), and 12+ anti-scope regression checks.

### Changed
- `docs/canonical-memory-setup.md` — clarified the parser rule (first backticked segment per bullet); added anti-pattern notes.

### Notes
- Phases 4–6 of the framework remain placeholders. Implementation Agent / Validation Agent / ralph loop ship in Sprint 4.
- Inferential sensors with calibration metadata are deferred to Sprint 5+ per PRD Open Question 3.
- The PRD's v0 amendment (Orchestrator-as-skill) is still pending backport to pattern docs; required before Sprint 5.

## [0.2.0] — 2026-04-25

Sprint 2 of an 8-sprint plan. See `.vibeflow/specs/yoke-v1-sprint-2.md` and
`.vibeflow/audits/yoke-v1-sprint-2-audit.md`.

### Added
- `agents/generator.md` — full Generator subagent definition (persona, behaviors, memory scope, allowed tools, restrictions per `.vibeflow/patterns/roles.md`).
- `/yoke:discover` (`skills/discover/SKILL.md`) — Phase 1, real implementation. Forked from [pe-menezes/vibeflow:discover](https://github.com/pe-menezes/vibeflow), namespaced under `/yoke:*`, switched to Yoke's PRD shape, wires the Generator subagent.
- `/yoke:tech-spec` (`skills/tech-spec/SKILL.md`) — Phase 2, real implementation. Forked from [pe-menezes/vibeflow:gen-spec](https://github.com/pe-menezes/vibeflow), aborts on missing/unapproved PRD.
- `/yoke:ask` (`skills/ask/SKILL.md`) — basic mediated query, text grep over a cloned canonical-memory repo at `~/.cache/yoke/canonical/<slug>/`, with empty-state UX.
- `lib/canonical-memory/query.sh` — bash 4 text grep with empty-state messaging, capped at 20 matches.
- `templates/prd.md` — manifesto's PRD shape: Product invariants, Business context, Known constraints (Technical/Regulatory/Organizational), Risks, Open questions.
- `templates/tech-spec.md` — manifesto's Tech Spec shape: Sprints with delivery objectives, tasks as use cases with binary acceptance criteria, contracts and interfaces, dependencies.
- `tests/smoke/sprint-2.test.sh` — 25-check smoke validating the new artifacts and anti-scope (placeholders untouched, hooks still skeletons).

### Notes
- Phases 3–6 of the framework remain placeholders. Validator subagent and Acceptance Contract land in Sprint 3.
- The PRD's v0 amendment (Orchestrator-as-skill) is not yet backported to pattern docs; Sprint 5 needs it before implementing the Orchestrator. Sprint 2 is consistent with the un-amended patterns.

## [0.1.0] — 2026-04-24

Sprint 1 of an 8-sprint plan. See `.vibeflow/specs/yoke-v1-sprint-1.md`.

### Added
- Plugin manifest: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
- Full directory layout per `.vibeflow/patterns/plugin-structure.md`:
  `skills/` (nine slash-command folders, only `bootstrap` implemented),
  `agents/` (five subagent placeholders),
  `hooks/` (four skeletons),
  `templates/` (six artifact placeholders + two real templates),
  `lib/` (seven script skeletons under `canonical-memory/`, `ralph-loop/`,
  `sensors/`),
  `docs/`, `tests/`, `examples/greenfield-payment-service/`.
- `/yoke:bootstrap` — initial setup for host projects: creates `.yoke/`,
  links a canonical-memory repo (existing or freshly `gh repo create`'d),
  verifies `gh` and bash 4+. Idempotent.
- Templates `templates/yoke-config.yaml` and `templates/project-claude-md.md`.
- Documentation: `docs/installation.md`, `docs/quickstart.md`,
  `docs/architecture.md` (1-page summary of `yoke.md`),
  `docs/canonical-memory-setup.md`.
- Top-level: `README.md`, `CHANGELOG.md` (this file), `CLAUDE.md`
  (instructions for Claude Code working on the plugin repo).

### Notes
- Phases 1–6 of the framework are not yet implemented; placeholder skills
  exist to validate the plugin manifest and command discovery.
- The Orchestrator placeholder ships under `agents/orchestrator.md` to match
  the unmodified `patterns/plugin-structure.md`. The PRD's v0 amendment
  moves it to `skills/orchestrator/SKILL.md` in Sprint 5.
