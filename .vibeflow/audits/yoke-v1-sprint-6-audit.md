# Audit Report: Yoke v1 — Sprint 6 (Hard bounds + 5 triggers + full Model C + progressive disclosure)

> Audited: 2026-04-25
> Spec: `.vibeflow/specs/yoke-v1-sprint-6.md`
> Plugin version: 0.6.0
> Dependencies satisfied: `.vibeflow/audits/yoke-v1-sprint-5-audit.md` (PASS)

**Verdict: PASS**

All 7 DoD checks satisfied. Pattern compliance clean across 4 patterns
(`model-c-governance.md`, `human-triggers.md`, `ralph-loop.md`,
`memory-model.md`). Sprint-6 smoke green (42/42); Sprint-5 (34/34);
Sprint-4 (29/29); Sprint-3 (27/27); Sprint-2 (18/18); Sprint-1
placeholder tests green; v0.6.0 manifests valid; CHANGELOG entry written.

**After Sprint 6, all manifesto-core invariants are operational.** The
PRD's success-criteria gates are now verifiable in code:

- Binding spec — Sprints 1–3
- Adversarial loop with hard bounds — Sprints 4 + 6
- Governed memory under full Model C — Sprints 5 + 6
- Five non-coalescable human triggers — Sprint 6
- Progressive disclosure (subgraph queries) — Sprint 6

Sprint 7 ships drift sensing; Sprint 8 ships polish + marketplace
publication. v1.0.0 = Sprint 8.

DoD #1 (hard-bound enforcement), #2 (Trigger-4 packet), #3 (5 distinct
trigger schemas), #4 (medium veto), #5 (high/regulatory paths), and #6
(progressive disclosure) carry intrinsic runtime-verification dependencies
on actually invoking these flows from a Claude Code session against a
real `gh`-authenticated test substrate. Strong in-code evidence (every
hook, escalator, and PR-strategy path exercised by 42-check smoke with
synthetic state) makes PASS the right verdict for the static artifacts.
Runtime is manual.

## DoD Checklist

- [x] **Check 1 — `check-hard-bounds.sh` enforces N + timeout + token budget; per-project overrides honored.** Evidence: smoke checks 1a–1d. Empty state → exit 0 (loop continues). Cycle limit at default 8 → exit 10. Per-project override `cycles_max: 100` lets cycles=8 pass → exit 0 (override correctly read from `.yoke/config.yaml` `overrides.hard_bounds:` block). Timeout (1 cycle + start in past) → exit 10. Defaults: N=8, timeout=14400 (4h), token_budget=200000.
- [x] **Check 2 — Hitting any bound triggers `escalate.sh` with structured arbitration packet; does NOT abort.** Evidence: smoke checks 2a–2c. `escalate.sh` requires `--reason` (exit 2 without). Divergence packet contains `trigger: 4` header, `reason`, `divergence_category`, `unresolved_sprint_contract` field, persists to `.yoke/.trigger4-packet.yaml`. Hard-bound packet additionally includes cycle/timeout/token state. The hook invokes `escalate.sh` then exits 10 — the loop pauses for arbitration, never aborts silently.
- [x] **Check 3 — Five triggers fire with non-coalescable schemas (verifiable by diff).** Evidence: smoke check 3 extracts each trigger's signature line and confirms 5/5 unique. Per-trigger options also verified: T1 (`approve`/`revise`/`restart` in `skills/discover/SKILL.md`), T2 (`approve`/`revise`/`back to PRD` in `skills/tech-spec/SKILL.md`), T3 (`ratify`/`revise`/`back to Tech Spec` in `skills/acceptance-contract/SKILL.md`), T4 (structured packet via `escalate.sh`, header `trigger: 4`), T5 (PR labeled `yoke-proposal` + impact-class label via `propose-write.sh`). All schemas have distinct shapes; no two could be confused.
- [x] **Check 4 — Medium-impact PRs comment-announce veto window; auto-merge after window closes.** Evidence: smoke checks 4. Default 24h veto window (configurable via `overrides.model_c.veto_window_hours`); dry-run output for medium impact prints `impact-medium` label, `veto window 24h`, "would post veto-window comment", "would configure: veto window 24h, then auto-merge". Override to 48h is honored end-to-end. Real-flow path: `gh pr comment` then `gh pr merge --auto --squash`.
- [x] **Check 5 — High-impact `auto-merge: never`; regulatory routes via CODEOWNERS.** Evidence: smoke checks 5. High-impact dry-run includes `impact-high` label and "auto-merge: never". Regulatory dry-run includes `impact-regulatory` label and CODEOWNERS routing notice. Real-flow path checks for CODEOWNERS at `CODEOWNERS`, `.github/CODEOWNERS`, or `docs/CODEOWNERS`; if absent, posts a warning comment but still opens the PR with `auto-merge: never`. Unknown impact strings still rejected with exit 4.
- [x] **Check 6 — `query.sh` returns subgraph (≤10 entries) on synthetic memory; <2s.** Evidence: smoke checks 6a–6d. `graph.sh list-edges` extracts `depends_on` from frontmatter. `graph.sh subgraph --depth 2` BFS-traverses A→B→C and correctly excludes unrelated D. `query.sh --subgraph-depth 2` with a unique seed token returns the full A→B→C subgraph. Performance: 0s on 100-entry synthetic memory (well under the 2s budget at 1000-entry scale).
- [x] **Check 7 — Craftsmanship: smoke exercises hard-bound + medium-veto + progressive disclosure; impact-class rules in Orchestrator skill.** Evidence: smoke section 7. `skills/orchestrator/SKILL.md` has "Impact classification rules" section with the 4-class table and keyword triggers. All 4 classes (regulatory / high / medium / low) enumerated. `docs/architecture.md` has Model C section. `docs/canonical-memory-setup.md` has CODEOWNERS subsection with recommended skeleton.

## Pattern Compliance

- [x] **`model-c-governance.md` — full 4-class path implemented.** `propose-write.sh` per-impact behavior matches the pattern's authority matrix exactly: `low` → auto-merge after CI; `medium` → veto window comment + auto-merge after window; `high` → `auto-merge: never` + sync approval; `regulatory` → `auto-merge: never` + CODEOWNERS routing. Veto-window length configurable. Unknown impact rejected with exit 4. The 5-criterion cascade (Sprint 5) still gates the proposition before `propose-write.sh` is reached.
- [x] **`human-triggers.md` — five distinct, non-coalescable triggers.** Each trigger's option set is unique (smoke check 3 verifies pairwise distinctness). T4 packet shape (`reason` / `divergence_category` / `state` / `unresolved_sprint_contract` / `escalation_to` / `decision_required`) matches the pattern's "arbitration packet" requirement. The four divergence sub-categories from §15.6 (quality-policies-broken / technical-infeasibility / business-conflict / acceptance-contract-violation) are implemented as `--category` values in `escalate.sh`.
- [x] **`ralph-loop.md` — hard bounds + Trigger-4 escalation.** `check-hard-bounds.sh` enforces all three: cycles_max, timeout_seconds, token_budget. Defaults match the pattern (5–8, 2–4h, configurable). Reaching any bound is treated as "signal that the task left the regime where ralph loop is reliable" per the pattern — exit 10 with packet, not abort. The hook invokes `escalate.sh` from a relative `BASH_SOURCE` path (Sprint-4 cwd lesson applied). `skills/implement/SKILL.md` termination paths now wire all four reasons (divergence / contract-conflict / hard-bound / infeasibility) to `escalate.sh`.
- [x] **`memory-model.md` — graph relationships traversable.** `graph.sh` understands all four edges (`depends_on` / `supersedes` / `applies_to` / `contradicts_with`) per the pattern. Frontmatter parsing handles both inline (`[a, b]`) and block (`- a` / `- b`) list forms. Subgraph traversal enables progressive disclosure operationally — agents never see canonical memory in full, only the relevant subgraph per query.

## Convention Compliance

`.vibeflow/conventions.md` Don'ts — applicable items honored:

- "Do NOT allow ralph loops without configured hard bounds" → ✓ `hooks/check-hard-bounds.sh` enforces; documented in `skills/implement/SKILL.md` termination paths; defaults baked in.
- "Do NOT canonize a pattern that contradicts existing canonical memory without human ratification" → ✓ regulatory and high impact paths require sync approval; criterion 5 (non-contradiction) still filters at the canonization-criteria step (Sprint 5).
- "Do NOT load entire canonical memory into context" → ✓ progressive disclosure now operational via `--subgraph-depth N` flag; subgraph cap at 10 entries.
- "Do NOT modify the Acceptance Contract during runtime" → ✓ contract-conflict reason fires `escalate.sh`; loop pauses for re-ratification.
- "Do NOT let a sprint contract contradict the Acceptance Contract" → ✓ Sprint-4's `check-contradiction` + Sprint-6's structured Trigger-4 packet (escalation_to / decision_required fields).

`Implementation Plan Conventions`:

- "Vertical slice before horizontal completeness" → ✓ Sprint 6 completes the governed-memory + adversarial-loop pillars at full Model C.
- "Every sprint ships an installable plugin" → ✓ v0.6.0 in plugin.json/marketplace.json/CHANGELOG.
- "Smoke test per sprint" → ✓ `tests/smoke/sprint-6.test.sh`, 42/42 PASS.
- "Bash scripts target bash 4+" → ✓ scripts use `BASH_SOURCE`, process substitution, `:-` defaults.

No new convention violations.

## Tests

- `tests/smoke/sprint-6.test.sh` → exit 0 (42/42 PASS) ✓
- `tests/smoke/sprint-5.test.sh` → exit 0 (34/34 PASS) ✓
- `tests/smoke/sprint-4.test.sh` → exit 0 (29/29 PASS) ✓
- `tests/smoke/sprint-3.test.sh` → exit 0 (27/27 PASS) ✓
- `tests/smoke/sprint-2.test.sh` → exit 0 (18/18 PASS) ✓
- `tests/plugin-install.test.sh` → exit 0 ✓
- `tests/skills-format.test.sh` → exit 0 ✓
- JSON validity: plugin.json + marketplace.json both 0.6.0 ✓

**No test failures.**

## Notes / process observations

### Two implementation fix-attempt rounds, six distinct issues closed

1. **Bundled fix #1**: subgraph test seed disambiguation (a unique token per file ensures the "first match" is predictable for the BFS root); impact-class regex flattening with per-class checks instead of a single multi-line regex; cross-sprint anti-scope cleanup for Sprints 3, 4, 5 smokes (items Sprint 6 advanced — `check-hard-bounds.sh`, `escalate.sh`, `graph.sh`, expanded `propose-write.sh` paths).
2. **Bundled fix #2**: Sprint-5 smoke check #10 was Sprint-5-specific ("only low-impact accepted"); Sprint 6 expanded the path to all 4 classes. Replaced with a cross-sprint robustness check ("unknown impact value still rejected with exit 4") that holds across Sprints 5+.

(2 fix attempts, well within the implement-skill cap. The cross-sprint anti-scope pitfall fired for the **fourth consecutive sprint**.)

### Cross-sprint anti-scope pitfall — pattern is now clear

This is the fourth audit (Sprint 3 → Sprint 4 → Sprint 5 → Sprint 6) where prior sprints' smokes broke because they over-asserted anti-scope on items that later sprints legitimately advanced. The fix is consistent (drop assertions on items that will be advanced), but the recurrence means **the convention should be canonized via `/vibeflow:teach` before Sprint 7**.

Concrete rule for the convention:
> Per-sprint smokes assert anti-scope only on items that NO later sprint advances within v1.0. For items advanced by later sprints, rely on the per-sprint audit at the time of writing — do not regression-check them across sprints.

### Manifesto-core completion

After Sprint 6:

- **Binding spec** ✓ — PRD/Tech-Spec/Acceptance-Contract artifacts with explicit human gates (Triggers 1, 2, 3).
- **Adversarial loop with hard bounds** ✓ — Implementation/Validation Agents iterate inside the Acceptance-Contract envelope; cycles_max + timeout + budget enforce termination; Trigger 4 packet escalates on divergence/contradiction/bound.
- **Governed memory** ✓ — Orchestrator-as-skill (3 modes) is sole writer; full Model C with low/medium/high/regulatory paths; canonization criteria filter cascade; query trace; subgraph progressive disclosure.
- **Five non-coalescable triggers** ✓ — distinct schemas for each phase gate.
- **Rippability metadata** ✓ — every canonical-memory write carries the mandatory frontmatter.

This is the PRD's success-criteria DoD gate "hard bounds are respected; five distinct human triggers fire". Sprint 7 (drift sensing) is the only remaining manifesto pillar.

### `BASH_SOURCE` hook convention applied

`check-hard-bounds.sh` uses `BASH_SOURCE` to find sibling `escalate.sh`,
applying the lesson from Sprint 4. This makes the hook portable across
host-project cwds. Worth ratifying as a `lib/`/`hooks/` convention via
`/vibeflow:teach`.

## Manual verification owed

Items intrinsic to this sprint, requiring runtime + a `gh`-authenticated test substrate:

1. Run `/yoke:implement` end-to-end with a real Acceptance Contract that has both passing and failing sensors; verify hard-bound enforcement triggers `escalate.sh` and produces a readable Trigger-4 packet.
2. Open a real medium-impact PR on a test canonical-memory repo; verify the veto-window comment appears and `gh pr merge --auto` is configured correctly.
3. Open a real high-impact PR and confirm `auto-merge: never` is set.
4. Open a real regulatory-impact PR with CODEOWNERS configured; verify Compliance reviewers are auto-assigned.
5. Verify subgraph progressive disclosure on a real canonical-memory repo with ≥1000 entries (current smoke uses 100 as a proxy).

## Pitfalls discovered (queue for `/vibeflow:teach`)

1. **High — cross-sprint anti-scope (4th occurrence).** Convention rule documented above; canonize before Sprint 7.
2. **Medium — `BASH_SOURCE` hook convention.** Hooks must locate sibling files via `BASH_SOURCE`, not relative paths or cwd. Already applied in `post-iteration.sh` (Sprint 4) and `check-hard-bounds.sh` (Sprint 6); ratify as a documented rule.
3. **Medium — content-diff distinctness checks.** Already canonized in Sprint 4 smoke; should be a documented smoke-design rule.
4. **Low — config-yaml override parser shape.** The awk-based override parser appears in 3 scripts now (`check-hard-bounds.sh`, `propose-write.sh`, `query.sh`). Could be deduplicated into a `lib/config/read-override.sh` helper. Not urgent; flag for Sprint 8 polish.

## Outstanding queue for `/vibeflow:teach`

Accumulated across audits, ranked by urgency:

1. **High — backport PRD v0 amendment** to `decisions.md`, `roles.md`, `plugin-structure.md`, `model-c-governance.md`. (Sprint 5 operationalized; pattern docs lag.)
2. **High — ratify deferred-anti-scope smoke convention** before Sprint 7.
3. **Medium — `BASH_SOURCE` hook convention** (Sprints 4 + 6).
4. **Medium — scaffolding-budget exception** (Sprint 1).
5. **Medium — content-diff distinctness check** (Sprint 4).
6. **Medium — `discover-from-claude-md.sh` parser sensitivity note** (Sprint 3).
7. **Medium — `query.sh --trace` shell-helper-for-audit-trails convention** (Sprint 5).
8. **Low — config-yaml override parser dedup** (Sprint 6, this audit).
9. **Low — real-flow CI workflow for PR path** (Sprint 5).

---

**Verdict: PASS.** Sprint 6 is implementation-complete. After Sprint 6,
**Yoke is minimally usable end-to-end for small projects** per the PRD's
success criteria. Plugin v0.6.0 ships with all manifesto-core invariants
operational. Runtime verification (real PR creation, real ralph loop
with hard bounds, real subgraph queries) is intrinsic manual work owed
before public release.

Ready to proceed to Sprint 7 (`.vibeflow/specs/yoke-v1-sprint-7.md`) —
Phase-6 drift sensing across codebase / canonical memory / historical
traces, with GitHub Actions scheduling.
