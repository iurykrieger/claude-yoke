# Spec: Yoke v1 — Sprint 8 — Polish + example + marketplace + v1.0.0 release

> Generated via /vibeflow:gen-spec on 2026-04-24
> PRD: `.vibeflow/prds/yoke-v1.md`
> Plugin version target: 1.0.0

## Objective

Ship Yoke 1.0.0 to the Claude Code marketplace with a working
end-to-end example, complete documentation, an honest lineage doc, and
CI gating future PRs against every sprint smoke test.

## Context

The framework is feature-complete after Sprint 7. Sprint 8 packages it
for adoption: the example proves the full flow works against a clean
project; docs let an external reviewer install and run without help;
the lineage doc credits the upstream sources (Vibeflow and Bedrock)
the framework draws from.

## Definition of Done

1. `examples/greenfield-payment-service/` runs the full flow end-to-end
   in < 30 minutes against a clean test environment, producing
   merge-ready code + ≥ 1 canonical-memory PR.
2. `README.md` includes badges, the install command, a quickstart link,
   and a screenshot/asciinema; an external reviewer (someone who has
   not seen Yoke) can install and run the example using only the docs.
3. `docs/quickstart.md`, `docs/architecture.md`, `docs/troubleshooting.md`,
   `docs/canonical-memory-setup.md`, `docs/scheduling-strategy.md`, and
   `docs/lineage.md` are all complete, internally consistent, and
   reviewed.
4. `.github/workflows/ci.yml` runs every sprint smoke test on every PR;
   CI badge in `README.md`; main is protected against red CI.
5. `marketplace.json` finalized; tag `v1.0.0` created; release notes
   published; `/plugin install yoke@yoke-marketplace` returns v1.0.0.
6. `docs/lineage.md` documents which Vibeflow and Bedrock skills were
   references and what was adapted, with explicit credit to upstream:
   - Vibeflow → <https://github.com/pe-menezes/vibeflow> (skills behind
     the Generator: PRD and Tech Spec drafting).
   - Bedrock → <https://github.com/iurykrieger/claude-bedrock> (skills
     behind the Orchestrator's canonical-memory operations: read,
     write, graph traversal).
   Per-skill mapping (origin file → Yoke artifact) and the date of the
   one-time fork are recorded.
7. **Craftsmanship gate:** no `conventions.md` Don'ts violated across
   the whole repo (full audit); every pattern in `.vibeflow/patterns/`
   is respected by the example; lineage credit is honest (no claim of
   ex-nihilo creation for adapted material).

## Scope

- `examples/greenfield-payment-service/` — full example project:
  `CLAUDE.md` with discoverable sensors; pre-populated canonical
  memory (per the decision the team makes at this sprint on PRD Open
  Question 9); completed `prd.md`, `tech-spec.md`,
  `acceptance-contract.md` for reference.
- All `docs/*.md` finalized.
- `.github/workflows/ci.yml` running every sprint smoke test.
- Marketplace publication artifacts (`marketplace.json`,
  `CHANGELOG.md` 1.0.0 entry, release notes).
- `docs/lineage.md` with explicit per-skill mapping and the upstream
  URLs.

## Anti-scope

- New features beyond bug-fix polish.
- Adversarial canonical-memory audit / post-deploy observation /
  starter pack of policies — all out of v1.0 (planned extensions).
- Multi-language docs — English only.
- Migration guide from "no Yoke" to "Yoke v1.0" — Yoke v1.0 is the
  starting point; migration happens at v2.

## Technical Decisions

- **Greenfield example, not migration.** Trade-off: skips legacy-codebase
  challenges; keeps the demo tight and predictable.
- **Lineage doc per-skill granularity.** Lists each skill in `skills/`
  that originated from upstream and what changed. Trade-off: extra
  doc work vs. honest crediting and easier upstream-aware reasoning
  for future developers.
- **CI gates every sprint smoke test.** Any failure blocks merge. No
  `--no-verify` allowed.
- **v1.0.0 release notes link back** to `yoke.md` (manifesto),
  `yoke-implementation-plan.md` (Tech Spec), and
  `.vibeflow/prds/yoke-v1.md` (PRD).
- **Pre-populated canonical memory in the example** — final answer to
  PRD Open Question 9 lands here. If the team chooses "starter pack",
  Sprint 8 ships the seed entries inside `examples/`.

## Applicable Patterns

- All nine patterns must be respected by the example.
- `plugin-structure.md` is the reference for the audit gate (DoD #7).

No new patterns introduced.

## Risks

- **R7 (bootstrap UX) revisits Sprint 1.** Final external-reviewer
  smoke is the test. **Mitigation:** Sprint-8 reviewer runs through
  `quickstart.md` cold; any friction blocks release.
- **Marketplace format drift.** Format may have changed since Sprint 1.
  **Mitigation:** verify against current `vibeflow-claude` and
  `claude-bedrock` manifests at release; fix before tagging.
- **Documentation rot.** Six months of incremental updates can leave
  inconsistencies. **Mitigation:** the audit reads every `docs/*.md`
  as a fresh user; flagged inconsistencies block release.
- **Lineage doc dishonesty.** If a skill is mostly upstream but
  presented as new, credit is broken. **Mitigation:** per-skill diff
  against the upstream commit at fork time is part of the audit.

## Dependencies

- `.vibeflow/specs/yoke-v1-sprint-7.md`
