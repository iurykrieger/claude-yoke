# Decision Log
> Newest first. Updated automatically by the architect agent.
> Manual bootstrap from `yoke.md` v1.0 manifesto.

### 2026-04-25 — Three runtime subagents only (supersedes "Five subagents")
**Decision:** Yoke v1.1 reduces `agents/` from five subagent files to three: `agents/generator.md`, `agents/validator.md`, `agents/orchestrator.md`. Spec-phase Generator/Validator subagent instances are eliminated; their personas move into the spec-phase skills (`/yoke:discover`, `/yoke:tech-spec`, `/yoke:acceptance-contract`). Generator and Validator are instantiated only at runtime, alongside the Orchestrator subagent (promoted back from a skill).
**Context:** The 2026-04-24 "Five subagents" decision materialized the Generator/Implementation and Validator/Validation distinctions as separate subagents to mitigate self-evaluation bias. In practice, spec-phase subagent spawns added no rigor over a well-prompted skill (Vibeflow's `discover`/`gen-spec` ship lean and work fine) while introducing Skill→Task→Subagent depth fragility, naming collision ("Generator" meaning two different things), and a missing Orchestrator runtime peer. Adversarial separation is retained at runtime — where it actually mitigates bias on code judgments — but discarded at spec phase, where the human at Triggers 1/2/3 is the adversary.
**Discarded alternatives:** Keep five subagents as-is (rejected: documented Skill→Task fragility + persona redundancy + naming confusion). Collapse to two subagents (Generator/Validator only, no Orchestrator subagent) (rejected: removes runtime canonical-memory consultation and canonization handoff, recreating the cold-start problem). Promote spec-phase subagents to skills but keep Implementation/Validation as separate runtime instances (rejected: keeps the naming collision; the Generator/Validator names are most natural at runtime).

### 2026-04-25 — Three agentified roles reaffirmed; instantiated only at runtime
**Decision:** The 2026-04-24 "Three agentified roles" decision (Generator, Validator, Orchestrator) is reaffirmed but clarified: each role is instantiated **exactly once** at runtime, not at both spec phase and runtime. Spec-phase work (Phases 1–3) is performed by skills with embedded persona prompts; the human is the adversary via Triggers 1/2/3. The roles' functional objectives (Generator: capture intent / generate code; Validator: judge against determinable signals; Orchestrator: mediate canonical memory + coordinate + canonize) remain.
**Context:** The original "Three roles" decision left the question of *how many instances per role* open. The 2026-04-24 "Five subagents" decision answered "two instances each (Generator/Implementation, Validator/Validation)". The 2026-04-25 "Three runtime subagents only" decision answers "one instance, at runtime". This entry consolidates those into a single re-affirmed contract.
**Discarded alternatives:** Two instances per role (rejected per supersession of "Five subagents"). Zero spec-phase agentification (skills only, no role concept at all in Phases 1–3) (rejected: the Generator persona is real and useful in skill prompts even when not a separate subagent — preserving the naming preserves doctrinal continuity).

### 2026-04-25 — Skills deliberate; subagents adapt (new invariant)
**Decision:** Yoke adopts a new architectural invariant: **skills handle deliberation on text artifacts (deterministic, low-stakes, human-driven dialogue); subagents handle adaptation at runtime (when reality diverges from the plan, when canonical memory needs to be consulted live, or when fresh canonization signal is best harvested at loop completion)**. Concretely: Phases 1–3 are skill-only (no subagent spawn); Phase 4 spawns three runtime subagents in parallel via a single Task batch.
**Context:** v1.0 mixed skills and subagents at every phase, which obscured the principle that drives the right tool choice. Skills are good at deterministic dialogue with the user (Trigger 1/2/3 ratification); subagents are good at adaptive runtime work (sensors firing, code diverging from plan, sprint contracts negotiated). Naming the invariant explicitly lets every future addition be evaluated against it: if the work is deterministic and human-gated, it goes in a skill; if the work is adaptive and runtime, it goes in a subagent.
**Discarded alternatives:** "Subagents everywhere" (rejected: added latency + control-flow fragility for spec phases, where the persona is the same as the skill prompt). "Skills everywhere, no runtime subagents" (rejected: collapses adversarial Generator/Validator runtime separation, which is the actual mitigation against self-evaluation bias on code).

### 2026-04-25 — Consult live, canonize on termination (new invariant)
**Decision:** Canonical memory is **consulted live** during the runtime loop (Orchestrator subagent reads via `lib/canonical-memory/query.sh` per cycle and surfaces relevant subgraph entries to `.yoke/query-trace.md`) but is **written to only at loop termination** — when `/yoke:implement`'s loop terminator fires (criteria pass, Trigger-4 escalation, hard bound, or infeasibility), it issues one final Orchestrator-only Task call with `mode=canonize`, which applies the five-criteria filter and proposes Model C writes via `lib/canonical-memory/propose-write.sh`. Mid-loop canonical-memory writes are forbidden.
**Context:** v1.0 ran canonization as a separate Phase-5 invocation (`/yoke:canonize`), which fired after `/yoke:implement` returned control to the user — context decayed, traces stale, candidates re-derived from archaeology. Mid-loop canonization writes (the original v1.1 PRD draft considered this) risked PR storms and conflicted with Model C's medium/high/regulatory governance windows. The compromise: read freely during the loop (cheap, helps Generator/Validator get context); write once at termination (preserves Model C governance + captures freshest signal). `/yoke:canonize` survives as a manual escape hatch for re-runs after model upgrades or auto-canonize failures.
**Discarded alternatives:** Continuous mid-loop canonization writes (rejected: PR storm risk; conflicts with Model C veto windows). Post-loop separate skill invocation only (rejected: cold-start problem from v1.0). No canonization handoff (rejected: makes canonical memory inert; defeats the framework's core learning loop).

### 2026-04-24 — Distribute Yoke as a standalone Claude Code plugin (strategy "a")
**Decision:** Yoke is packaged and distributed as an independent Claude Code plugin (`.claude-plugin/plugin.json` + `marketplace.json`). Skills, agents, hooks, templates and helper scripts all live inside this single plugin repo. Layout follows `vibeflow-claude` and `claude-bedrock`.
**Context:** The plugin format is the unit of distribution Claude Code already supports. Yoke must install via `/plugin install` and expose `/yoke:*` commands without requiring users to configure infrastructure.
**Discarded alternatives:** Plugin-of-plugin layered on `vibeflow-claude` (rejected: tight coupling, conflicts with the embed-fork-once decision). Remote service / SaaS (rejected: distribution model mismatch with Claude Code).

### 2026-04-24 — Bootstrap Yoke v1 manually, not recursively
**Decision:** Yoke v1 is built without using Yoke. Vibeflow and Bedrock can be installed separately during construction as scaffolding aids, but the v1 product is independent of any running Yoke instance.
**Context:** Yoke depends on a populated canonical memory to function, but canonical memory is populated by using Yoke. Recursive bootstrap is therefore infinite. Manual bootstrap of v1 breaks the loop. Yoke 1.1+ may then be developed using Yoke 1.0 — that transition is planned, not assumed.
**Discarded alternatives:** Bootstrap with a seeded canonical memory (rejected: seed has to come from somewhere — pushes the bootstrap problem one step). Bootstrap by using Vibeflow as a stand-in for Yoke (rejected: artifact shapes diverge, contaminates the v1 spec/test data).

### 2026-04-24 — Vertical slice before horizontal completeness (sprint sequencing)
**Decision:** The first useful sprint produces a minimum end-to-end path (idea → PRD → merged code), even if rough. Subsequent sprints add depth to specific phases. Sprints 1–3 are vertical slice; 4–6 are horizontal depth; 7–8 are longitudinal layers.
**Context:** Building one phase at a time risks discovering integration problems at the end, when refactor cost is highest. Vertical-first surfaces packaging, plugin format, agent spawning and skill orchestration issues during Sprint 1, when fixing them is cheap.
**Discarded alternatives:** Build each phase to completion before moving on (rejected: integration risk concentrated at the end). Parallel work streams per phase (rejected: coordination overhead, no single shippable artifact at any point).

### 2026-04-24 — Each sprint produces an installable, exercisable plugin artifact
**Decision:** At the end of every sprint the Yoke plugin is installable via `/plugin install` and exercisable up to the coverage that sprint added. Every sprint ships a versioned bump (0.1.0 → 0.2.0 → … → 1.0.0).
**Context:** Distribution, installation, marketplace integration and Claude Code interop are the kinds of failures that surface only when shipped. Forcing each sprint through a real install path keeps those failures cheap.
**Discarded alternatives:** Big-bang ship at v1.0 (rejected: distribution failures at the worst time). Internal-only artifacts until v1.0 (rejected: same problem).

### 2026-04-24 — Five subagents (Generator, Validator, Orchestrator, Implementation, Validation) as distinct entities
**Decision:** The Generator/Implementation distinction and the Validator/Validation distinction are materialized as five separate subagent definitions in `agents/`, not as runtime modes of three agents. Each subagent has its own prompt, persona, memory scope and tool list.
**Context:** The manifesto stresses that runtime instances are functionally distinct from spec-phase roles (different objective: completeness vs intent capture; rigor vs criterion expression). Conflating them into one prompt-with-mode is the failure mode that recreates self-evaluation bias.
**Discarded alternatives:** Three subagents with mode flags (rejected: prompts contaminate across modes; harder to evolve roles independently). One mega-agent (rejected: defeats role separation entirely).

### 2026-04-24 — Sensors are discovered from the project's CLAUDE.md (with fallback)
**Decision:** When the Validator drafts an Acceptance Contract, it discovers available sensors by parsing the host project's `CLAUDE.md` for marked sections (`## Testing`, `## Linting`, `## Build`, etc.). If those sections are absent, the Validator asks the user directly.
**Context:** `CLAUDE.md` is the conventional place where project-level commands live in a Claude Code repo. Reusing it avoids inventing a Yoke-specific config file for what is essentially "how do I lint/test/build this project".
**Discarded alternatives:** Yoke-specific sensor config file (rejected: redundant; users already maintain CLAUDE.md). Auto-detection via heuristics on package files (rejected: noisy, language-specific, fragile).

### 2026-04-24 — Working memory lives in `.yoke/` inside the project repo
**Decision:** Per-task working memory (`prd.md`, `tech-spec.md`, `acceptance-contract.md`, `progress.md`, `contracts.md`, `query-trace.md`, `config.yaml`) lives in a `.yoke/` directory at the project root, created by `/yoke:bootstrap`.
**Context:** Working memory is per-task and must travel with the project repo for recovery and audit. Storing it in a sibling directory or external store would split the audit trail and complicate recovery protocols.
**Discarded alternatives:** External store (rejected: split audit trail). Per-branch storage in git (rejected: ephemeral content pollutes history). User home directory (rejected: not portable across machines/teammates).

### 2026-04-24 — Canonical memory lives in a separate git repository, created by `/yoke:bootstrap`
**Decision:** Each Yoke installation has a dedicated canonical-memory repo, created or pointed-to during bootstrap. The substrate is git-native (manifesto decision) and physically distinct from any project repo. It is not a submodule.
**Context:** Canonical memory is organization-wide, while project repos are scoped per project. Separation matches the blast-radius asymmetry: working memory corruption affects one task; canonical memory corruption affects the organization. Storing both in the same repo would require fine-grained ACLs to enforce Model C.
**Discarded alternatives:** Embedded folder inside each project (rejected: duplication, drift, breaks org-wide doctrine). Single shared submodule across projects (rejected: submodule UX is hostile and update protocol clashes with PR-based ratification).

### 2026-04-24 — Schedule drift sensing via GitHub Actions (initial recommendation)
**Decision:** Phase 6 background drift sensing is scheduled via GitHub Actions in the project repo. Final decision deferred to Sprint 7, but the recommended starting point is Actions over local cron or local daemon.
**Context:** Yoke is already git-native (canonical memory is a git repo, ratification is PR merge). Actions reuses that surface for free, gives every team a familiar audit trail, and avoids requiring users to run a daemon. Local cron and local daemons remain on the table for offline/internal contexts.
**Discarded alternatives:** Local cron (rejected as default: per-machine drift, not collaborative). Local daemon (rejected as default: opex burden, hard to debug across teammates).

### 2026-04-24 — Plan recursive transition from v1.1 onwards (dogfooding)
**Decision:** v1.0 is built manually. Once v1.0 ships and a real canonical memory exists, future Yoke development (v1.1 onwards) is intended to use Yoke itself. The transition is planned, not assumed — and it is documented so the change is conscious.
**Context:** Closes the bootstrap loop without making v1 dependent on something that does not yet exist. Once v1.0 is real, recursion stops being infinite and becomes a useful dogfooding signal.
**Discarded alternatives:** Refuse recursion forever (rejected: throws away the dogfooding loop, which is the cleanest source of canonization data). Force recursion at v1.0 (rejected: see manual-bootstrap decision).

### 2026-04-24 — Three agentified roles (Generator, Validator, Orchestrator)
**Decision:** Yoke structures both spec generation and runtime around three agentified roles with disjoint functional objectives. Generator produces spec artifacts; Validator judges conformance; Orchestrator mediates canonical memory, coordinates runtime and canonizes learnings.
**Context:** Self-evaluation bias is documented (Milvus): solo agents systematically approve output that should fail. Generator/Evaluator separation is the known architectural workaround. Yoke applies it on two layers — pre-runtime (Generator vs Validator producing PRD/Spec vs Acceptance Contract) and runtime (Implementation Agent vs Validation Agent).
**Discarded alternatives:** Single-agent pipeline with self-review (rejected: self-evaluation bias). Two-agent pipeline (Generator + Validator) without an Orchestrator (rejected: no single owner of feedback lifecycle and canonization).

### 2026-04-24 — Acceptance Contract as a binding pre-runtime artifact
**Decision:** Before any code is written, the user approves an Acceptance Contract produced by the Validator. From that point on, "done" is operationally defined as "passes every criterion in the Contract". Any change during runtime requires a fresh ratification.
**Context:** Unlike Anthropic-style sprint contracts (negotiated between agents during runtime), the Acceptance Contract is negotiated between the human and the agents BEFORE runtime starts. It is binding for the whole task. Addresses ambiguity of "done" and fixes the envelope inside which sprint contracts can be negotiated.
**Discarded alternatives:** Define "done" only via emergent sprint contracts (rejected: allows drift without human ratification). Define "done" only at the merge boundary (rejected: violates shift-feedback-left).

### 2026-04-24 — Model C governance (contextual authority by impact class)
**Decision:** Authority to write to canonical memory varies by the impact class of the proposition. Low impact auto-applies; medium notifies-and-applies with a veto window; high requires synchronous ratification; regulatory MUST policies require Compliance.
**Context:** Treating every write equally creates either a bottleneck (everything sync-ratified) or a risk surface (nothing ratified). Model C differentiates by blast radius.
**Discarded alternatives:** Model A — every write auto-applied (risk). Model B — every write requires synchronous ratification (bottleneck + human fatigue).

### 2026-04-24 — Git-native write protocol via pull requests
**Decision:** The Orchestrator writes to canonical memory by opening pull requests against the repository that serves as the substrate. Ratification is the PR merge itself.
**Context:** Reuses a well-known workflow (PR review). Versioning, diff, history and rollback (`git revert`) are native. Auditability is structurally complete in the PR history.
**Discarded alternatives:** Custom ratification API (rejected: reinvents an already familiar workflow). Direct DB writes with audit log (rejected: rollback is non-trivial and the trail is less human-readable).

### 2026-04-24 — Canonical memory as markdown + frontmatter + graph (over MCP)
**Decision:** Canonical memory uses markdown as primary format, YAML frontmatter carries metadata and relationships, and relationships form a graph queryable through MCP.
**Context:** Markdown is human-readable and diff-friendly. Frontmatter carries structured metadata without leaving the format. The graph enables operationally viable progressive disclosure — the Orchestrator loads only the subgraph relevant to the current phase/task.
**Discarded alternatives:** Pure JSON (rejected: harder to read in PR review). Triple store (rejected: overkill for the expected volume; reduces human auditability).

### 2026-04-24 — Embed upstream skills as a single fork at creation time
**Decision:** Yoke embeds copies of Vibeflow and Bedrock skills at creation time. From then on those skills evolve autonomously inside Yoke. There is no continuous port from upstream.
**Context:** Pinning to upstream releases would create permanent overhead and risk introducing changes that are incompatible with Yoke's design. Internal consistency is guaranteed because all three agents consult the same versioned set within the framework.
**Discarded alternatives:** External dependency tracking upstream (rejected: incompatibility risk). Re-implementing from scratch without reusing upstream skills (rejected: unnecessary cost; lineage from Vibeflow/Bedrock is genuine and worth crediting).

### 2026-04-24 — External canonical-memory substrate (not embedded)
**Decision:** The substrate where canonical memory persists is an external dependency of Yoke, not embedded. Reference implementation is Claude Bedrock; it is replaceable by any versioned store reachable over MCP or equivalent.
**Context:** Organizational content is org-specific. Yoke embeds the access (skills), not the content.
**Discarded alternatives:** Embedded substrate with a generic seed (rejected: content is non-generic by definition). No canonical substrate at all (rejected: would negate the "governed memory" pillar of the framework).

### 2026-04-24 — Hard bounds on ralph loops with human escalation
**Decision:** Ralph loops have configured ceilings (N = 5–8 cycles, timeout 2–4 h, budget per task class). Reaching any ceiling triggers human escalation, not retry.
**Context:** Agents in subtle disagreement can iterate indefinitely while agreeing they are "almost there". Hard bounds guarantee termination and address a documented failure of the discipline. Hitting a ceiling is not a failure — it is a signal that the task left the regime where the ralph loop is reliable.
**Discarded alternatives:** Loops without ceilings (rejected: known failure of the discipline). Ceiling that aborts the task without escalation (rejected: loses context valuable for canonization).

### 2026-04-24 — "Every rule gets periodically re-tested against the current model" (rippability)
**Decision:** Yoke explicitly adopts the inverse of the prevailing "every mistake gets a new rule" reflex. Every guide in canonical memory is periodically re-tested against the current underlying model; major model upgrades are an explicit review trigger.
**Context:** Each item in canonical memory encodes an assumption about what the model could not do well at the time of ratification. When the model evolves, the item turns into overhead — it costs tokens and pollutes context. Anthropic reported that Opus 4.5 eliminated the "context anxiety" Sonnet 4.5 had; mitigation mechanisms became obsolete.
**Discarded alternatives:** Keeping rules indefinitely (rejected: documented over-constraining; ETH Zurich's study of 138 AGENTS.md files showed 20%+ token overhead).

### 2026-04-24 — Intermediate stance on agent-to-agent review
**Decision:** Automated Implementation↔Validation loops operate inside hard bounds with mandatory human escalation on divergence, on a sprint contract that contradicts the Acceptance Contract, or when bounds are reached. Neither full automation (OpenAI-style) nor human review on every PR (Stripe-style).
**Context:** The community has not converged. Yoke takes an explicit operational position — the third point — rather than claiming to solve the open problem.
**Discarded alternatives:** Full automation (OpenAI-style; rejected: accepts self-evaluation bias). Full human review (Stripe-style; rejected: violates shift-feedback-left and feeds review fatigue).
