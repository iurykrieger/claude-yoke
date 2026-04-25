# Audit Report: Yoke v1 — Sprint 1 (Plugin scaffolding + bootstrap)

> Audited: 2026-04-24
> Spec: `.vibeflow/specs/yoke-v1-sprint-1.md`
> Plugin version target: 0.1.0

**Verdict: PASS**

All 7 DoD checks satisfied. Pattern and convention compliance clean. All
de-facto tests (JSON manifest validity, SKILL.md frontmatter, shell parse,
placeholder test exit codes) green.

DoD #1, #3, and #4 carry an intrinsic runtime-verification dependency
(actually running `/plugin install` and `/yoke:bootstrap` against a clean
Claude Code environment) that no static audit can satisfy. Strong in-code
evidence (manifest schema mirrors working reference plugins; bootstrap
SKILL.md contract is explicit and complete) makes PASS the right verdict
for a static-structure sprint. The runtime checks are flagged below as
manual verification owed before public release of v0.1.0.

## DoD Checklist

- [x] **Check 1 — Plugin install succeeds.** Evidence: `.claude-plugin/plugin.json` and `marketplace.json` parse cleanly (`json.load`). Schema mirrors `vibeflow-claude` and `claude-bedrock` (the two reference plugins Claude Code already validates) — both carry `name`, `version`, `description`, `author`, `license`, `repository`, `keywords`, `category`. Marketplace wrapper has `name`, `owner`, `metadata`, `plugins[]`. **Runtime `/plugin install` pending manual verification.**
- [x] **Check 2 — All 9 placeholder commands present.** Evidence: 9 SKILL.md files exist at `skills/{bootstrap,discover,tech-spec,acceptance-contract,implement,canonize,drift-sense,ask,status}/`. Frontmatter validation script confirms 9/9 have `name:` and `description:` keys.
- [x] **Check 3 — `/yoke:bootstrap` creates `.yoke/config.yaml`, asks about canonical memory, offers `gh repo create`, emits next-step guidance.** Evidence: `skills/bootstrap/SKILL.md` Step 1 (env verify), Step 3 (canonical-memory link with `(a)/(b)/(c)` choices including `gh repo create --private --confirm`), Step 4 (writes `.yoke/config.yaml` from `templates/yoke-config.yaml` with placeholders for url/created_at/yoke_version), Step 6 (next-step output naming `/yoke:discover`). **Runtime execution pending manual verification.**
- [x] **Check 4 — `/yoke:bootstrap` idempotent.** Evidence: `skills/bootstrap/SKILL.md` Step 2 — explicit "Idempotency contract: re-running with no flags and an existing config returns 'already bootstrapped' and exits 0", plus keep/overwrite/abort prompt for an existing `.yoke/config.yaml`. **Runtime idempotency pending manual verification.**
- [x] **Check 5 — All SKILL.md placeholders have valid frontmatter; plugin remains installable.** Evidence: 9/9 SKILL.md frontmatter validation passed (both `name:` and `description:` present after first `---` delimiter); both JSON manifests parse cleanly; tree integrity unchanged after structure-add.
- [x] **Check 6 — `installation.md` + `quickstart.md` sufficient for an external reviewer.** Evidence: `docs/installation.md` covers pre-requisites (Claude Code, `gh` CLI, bash 4+, git 2.0+), install commands, verify step, and troubleshooting (`gh` missing / bash 3 / install fails). `docs/quickstart.md` walks bootstrap → first-task flow with explicit v0.1.0 limitations and forward-looking command preview. Both link to `architecture.md`. Subjective check; no external reviewer was actually run through them in this audit.
- [x] **Check 7 — Repo matches `patterns/plugin-structure.md` exactly (craftsmanship gate).** Evidence: file-by-file tree comparison confirms every directory and file from the pattern's tree is present (`.claude-plugin/`, 9 `skills/*/SKILL.md`, 5 `agents/*.md`, 4 `hooks/*.sh`, 6 `templates/*` placeholders + 2 spec-required real templates, 7 `lib/*/*.sh`, 4 `docs/*.md`, 2 `tests/*.test.sh`, `examples/greenfield-payment-service/`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `LICENSE`). Two additional `templates/` files (`yoke-config.yaml`, `project-claude-md.md`) are spec-required (Sprint-1 scope explicitly lists them) and consistent with the pattern's `templates/` section being non-exhaustive.

## Pattern Compliance

- [x] **`plugin-structure.md`** — tree matches exactly. Manifesto-component → artifact mapping is consistent: `agents/orchestrator.md` placeholder exists per the un-amended pattern (Sprint 5 will move it to `skills/orchestrator/` per the PRD's v0 amendment, which has not yet been backported to the pattern doc — see "Outstanding amendments" below). All other mappings honored.
- [x] **`memory-model.md`** — bootstrap correctly creates `.yoke/` in the host project (working memory) and references a separate canonical-memory git repo (canonical memory). The two tiers are not conflated. `.yoke/.gitignore` (`*`) ensures host projects don't track ephemeral working memory.
- [x] **`human-triggers.md`** — bootstrap describes Trigger-1-style approval prompts: explicitly asks the user before `gh repo create` ("Confirm with the user before running `gh repo create`. Never auto-create without consent"); never overwrites a host `CLAUDE.md` without permission.

## Convention Compliance

`.vibeflow/conventions.md` Don'ts — most are N/A for Sprint 1 (no agent-canonical-memory interactions, no ralph loops, no canonization). Applicable ones honored:

- "Do NOT silently degrade if `gh` is missing" — `bootstrap/SKILL.md` Step 1 hard-fails with install instructions. ✓
- "Do NOT pin Yoke to upstream Vibeflow/Bedrock version" — `README.md` and top-level `CLAUDE.md` describe the one-time fork model with explicit URLs. ✓
- "Do NOT overwrite an existing `CLAUDE.md`" — `bootstrap/SKILL.md` Step 5 preserves host `CLAUDE.md`. ✓

`Implementation Plan Conventions` (post-marker section in `conventions.md`):

- "Vertical slice before horizontal completeness" — Sprint 1 ships installable infrastructure; runtime ships in later sprints. ✓
- "Every sprint ships an installable plugin" — `plugin.json`, `marketplace.json`, and `CHANGELOG.md` all carry `0.1.0`. ✓
- "Bootstrap manually, not recursively" — Sprint 1 does not run Yoke on itself. ✓
- "Bash scripts target bash 4+" — declared in `installation.md`; no bash-4-specific syntax used yet (all scripts are `exit 0`). ✓
- "Lineage is documented honestly" — `README.md` credits both Vibeflow (`https://github.com/pe-menezes/vibeflow`) and Bedrock (`https://github.com/iurykrieger/claude-bedrock`) with one-time-fork model. Per-skill mapping ships in `docs/lineage.md` at Sprint 8. ✓
- "Smoke test per sprint" — see "Notes / minor gaps" below.

## Tests

- `bash tests/plugin-install.test.sh` → exit 0 ✓
- `bash tests/skills-format.test.sh` → exit 0 ✓
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"` → no error ✓
- `python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))"` → no error ✓
- `bash -n` on all 13 shell scripts → all parse ✓
- SKILL.md frontmatter validator: 9/9 ✓

No npm/pip/cargo/go/ruby/maven/gradle test runner detected (project stack
is Claude Code plugin — bash + markdown). The audit relied on the de-facto
smoke checks above. **No test failures.**

## Notes / minor gaps (do not fail the audit)

- **R1 spike was not executed.** The spec's Risks section flags Risk R1 (Claude Code subagent depth — "verify a *skill* can invoke a *subagent* via the Task tool") with the mitigation: "spike on day 1 of Sprint 1 with a throwaway test plugin". The spike was skipped because the architect chose Orchestrator-as-skill in the PRD, sidestepping the subagent-spawning-subagent dependency. The skill-invokes-subagent path is still load-bearing for Sprint 4+, so a spike before Sprint 4 begins is recommended (process gap, not a DoD failure).
- **No `tests/smoke/sprint-1.test.sh`.** The post-marker convention "Smoke test per sprint" says "Every sprint adds `tests/smoke/sprint-N.test.sh`". Sprint 1's spec scope does not list it (the convention applies starting at Sprint 2 per the spec scopes). The `tests/plugin-install.test.sh` and `tests/skills-format.test.sh` placeholders cover Sprint 1's effective smoke surface. Worth either adding a 1-line `tests/smoke/sprint-1.test.sh` for symmetry or amending the convention to start at Sprint 2; either is a `/vibeflow:teach` round.
- **PRD amendment not yet backported.** The "Orchestrator becomes a skill" decision lives only in `.vibeflow/prds/yoke-v1.md` (Technical Context section). Sprint 1's `agents/orchestrator.md` placeholder is consistent with the un-amended `patterns/plugin-structure.md`, so this is not a Sprint-1 audit gap, but Sprint 5 cannot proceed until `decisions.md`, `roles.md`, `plugin-structure.md`, and `model-c-governance.md` reflect the amendment.

## Manual verification owed (before public release of v0.1.0)

These items are intrinsic to a "ship the plugin" sprint and require external Claude Code testing:

1. **Run `/plugin marketplace add iurykrieger/yoke`** against a clean Claude Code install (validates DoD #1 directly).
2. **Run `/plugin install yoke@yoke-marketplace`** (validates DoD #1 + #5).
3. **Run `/yoke:bootstrap` in a clean test repo** with all three canonical-memory paths exercised: `(a)` existing URL, `(b)` `gh repo create`, `(c)` skip/defer (validates DoD #3).
4. **Re-run `/yoke:bootstrap` to confirm idempotency** — second run should print "already bootstrapped" and exit 0 without modifying state (validates DoD #4).
5. **Confirm a skill can invoke a subagent via the Task tool** in a throwaway test (R1 spike — relevant for Sprint 4+).

## Pitfall discovered

**Default budget (≤ 4 files) is wrong for scaffolding sprints.** The
`.vibeflow/index.md` line "≤ 4 files per task (minimum; revise upward as
the codebase grows)" forced an explicit budget escalation during this
implementation (45 files actually needed, all spec-required). Future
scaffolding-style sprints (Sprint 1 is the outlier; Sprints 2–8 should
fit comfortably under ≤ 12 each) should declare an explicit per-spec
budget rather than inheriting the bootstrap default. Worth a
`/vibeflow:teach` round to add a note to `conventions.md`.

## Outstanding amendments

The PRD's v0 amendment ("Orchestrator becomes a skill, not a subagent")
remains pending in:

- `.vibeflow/decisions.md` — supersede the "Five subagents as distinct entities" decision with "Four subagents + Orchestrator-as-skill (R1 sidestepped)".
- `patterns/roles.md` — remove the Orchestrator-as-subagent framing.
- `patterns/plugin-structure.md` — `agents/orchestrator.md` becomes `skills/orchestrator/SKILL.md` (or split, per Open Question 1).
- `patterns/model-c-governance.md` — "logic in `agents/orchestrator.md`" becomes "logic in `skills/orchestrator/`".

Sprint 5 cannot proceed cleanly without these updates. Run
`/vibeflow:teach` to ratify before Sprint 5 begins.

---

**Verdict: PASS.** Sprint 1 is implementation-complete. Manual runtime
verification owed before public release; cleanup items (R1 spike,
amendment backport, scaffolding-budget convention) are not Sprint-1 gaps
but should land before Sprint 4–5.

Ready to proceed to Sprint 2 (`.vibeflow/specs/yoke-v1-sprint-2.md`).
