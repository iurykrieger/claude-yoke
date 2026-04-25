# Spec: Yoke v1 — Sprint 5 — Orchestrator skill + canonization + git-native low-impact

> Generated via /vibeflow:gen-spec on 2026-04-24
> PRD: `.vibeflow/prds/yoke-v1.md`
> Plugin version target: 0.5.0

## Objective

Light up the canonical-memory write path. The Orchestrator skill ships
all three modes (mediator, runtime coordinator, canonizer).
`/yoke:canonize` reads working memory, applies canonization criteria,
and proposes low-impact writes via PRs on the canonical-memory repo.
`/yoke:ask` is now mediated and produces a query trace.

## Context

After Sprint 5 the system has a closed feedback loop: a task can
complete, the Orchestrator can canonize a learning, and the next task
can `/yoke:ask` and find it. Medium- and high-impact paths and full
governance ship in Sprint 6.

## Definition of Done

1. The Orchestrator skill (`skills/orchestrator/SKILL.md` or split per
   PRD Open Question 1) declares its three modes explicitly when invoked,
   so traces show which mode emitted each operation.
2. `/yoke:ask` is mediated: every query writes to `.yoke/query-trace.md`;
   Generator and Validator now go through the skill, not direct grep.
3. `lib/canonical-memory/canonization-criteria.sh` evaluates the five
   criteria (repeatability, generality, stability, impact,
   non-contradiction) and emits a candidate list with score + reason.
   Runs in < 5s on a synthetic 1000-entry canonical memory.
4. `/yoke:canonize` after a successful task produces ≥0 propositions; on
   a sprint with rich `contracts.md`, ≥1 candidate is proposed with
   traceability back to the originating trace.
5. `lib/canonical-memory/propose-write.sh` opens a PR on the canonical
   repo with `yoke-proposal` and `impact-low` labels, configures
   auto-merge after CI checks (does not force-merge), and fails loudly
   if `gh` is missing.
6. `tests/smoke/sprint-5.test.sh` runs the full pipeline through
   canonization; a low-impact proposition auto-merges; the next task's
   `/yoke:ask` finds the canonized content.
7. **Craftsmanship gate:** any Generator or Validator attempt to access
   canonical memory bypassing the Orchestrator skill is detected and
   flagged (per `patterns/model-c-governance.md`); no `conventions.md`
   Don'ts violated.

## Scope

- `skills/orchestrator/SKILL.md` — full Orchestrator skill, three modes
  declared as explicit operating contracts.
- Real `skills/canonize/SKILL.md`.
- Update `skills/ask/SKILL.md` to be mediated (Sprint-2 grep moves
  behind the skill).
- `lib/canonical-memory/query.sh` — refined; still no progressive
  disclosure (Sprint 6).
- `lib/canonical-memory/canonization-criteria.sh` — five-criterion
  cascade.
- `lib/canonical-memory/propose-write.sh` — low-impact path only.
- `templates/canonical-entry-frontmatter.yaml` — mandatory rippability
  metadata (`ratified_at`, `model_calibrated_against`, `last_validated`,
  `traceability`, `impact_level`) + relationship edges.
- `tests/smoke/sprint-5.test.sh` (uses a TEST canonical-memory repo).

## Anti-scope

- Medium and high-impact Model C paths — Sprint 6.
- Progressive disclosure / graph queries — Sprint 6.
- Hard bounds / Trigger-4 formalization — Sprint 6.
- Drift sensing — Sprint 7.
- Production canonical-memory writes — Sprint-5 tests target a TEST
  canonical-memory repo only; real-world use waits for medium-impact
  veto windows in Sprint 6.

## Technical Decisions

- **Upstream source for canonical-memory operations:** the read, write,
  and graph-traversal scripts under `lib/canonical-memory/` are forked
  from <https://github.com/iurykrieger/claude-bedrock> (the canonical
  memory MCP layer). Fork is one-time at the start of Sprint 5; Yoke
  evolves them autonomously (per `decisions.md` — "Embed upstream skills
  as a single fork at creation time"). The Orchestrator skill itself is
  Yoke-native (not in upstream Bedrock). Adaptation work on the Bedrock
  scripts: namespace under `lib/canonical-memory/`, layer Yoke's
  five-criteria canonization filter and Model C impact classes on top
  of Bedrock's read/write/graph primitives, and wire `propose-write.sh`
  to the `gh` CLI PR flow. Lineage recorded per-script in
  `docs/lineage.md` at Sprint 8.
- **Orchestrator skill modes are explicit declarations** (mediator /
  runtime coordinator / canonizer). Trade-off: a slightly noisier prompt
  vs. unambiguous traces of which mode acted. Mode declarations are
  written to `.yoke/query-trace.md` alongside queries.
- **Canonization-criteria thresholds** (N for repeatability, M for
  generality, period for stability) are configurable in
  `.yoke/config.yaml` with safe defaults documented.
- **PR labels are mandatory.** `propose-write.sh` fails if labels can't
  be applied. Trade-off: tighter dependency on `gh` permissions vs.
  guaranteed fleet-wide auditability.
- **Auto-merge configured but not forced.** CI checks still run.
  Trade-off: a slow CI delays canonization vs. doctrine pollution from
  failing checks.
- **Sprint-5 tests use a TEST canonical-memory repo.** Trade-off: extra
  setup vs. risk of polluting production memory before Sprint 6 ships
  human-veto paths.
- **Open Question 1 (skill location) deferred to during-implementation.**
  The spec ships either layout (single skill or split) — pick one early
  and document it in `plugin-structure.md` via `/vibeflow:teach`.

## Applicable Patterns

- `roles.md` — Orchestrator (now as skill, three modes).
- `model-c-governance.md` — low-impact path; PR labels; canonization
  criteria.
- `memory-model.md` — canonical-memory format, mandatory frontmatter,
  relationship edges.
- `phase-flow.md` — Phase 5 entry.
- `human-triggers.md` — Trigger-5 surface (canonization PR opened).

No new patterns introduced — the Orchestrator-as-skill amendment from
the PRD updates `roles.md` rather than introducing a new pattern.

## Risks

- **R2 — progressive-disclosure latency at scale.** Sprint 5 measures
  with synthetic 1000-entry canonical memory before Sprint 6 ships
  the subgraph implementation. **Mitigation:** instrument query.sh with
  timing in Sprint 5; if > 2s on 1000 entries, evaluate SQLite index in
  Sprint 6. Acceptable to defer index to v1.1 if borderline.
- **PRD Open Question 9 — empty canonical memory bootstraps a poor
  example UX.** Sprint 5 reveals it. **Mitigation:** decision on starter
  pack content can be made when Sprint 8 lands; doesn't block Sprint 5.
- **Auto-merge of bad propositions.** Sprint 5 has no human-veto path;
  bad criteria pollute the test repo. **Mitigation:** test repo only;
  Sprint 6 ships the medium-impact veto window for real-world use.
- **Mode-declaration discipline.** If the skill prompt drifts, modes
  collapse and traces lose value. **Mitigation:** mode-declaration
  presence in trace is part of the smoke test.

## Dependencies

- `.vibeflow/specs/yoke-v1-sprint-4.md`
