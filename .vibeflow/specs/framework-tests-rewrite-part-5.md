# Spec: Framework tests rewrite — Part 5 (project artifacts & docs)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> .vibeflow/prds/framework-tests-rewrite.md

## Objective

Add concept-shaped tests for the example project completeness and the
docs / lineage / README / CHANGELOG honesty.

## Context

`tests/smoke/sprint-8.test.sh` currently bundles example-project
assertions, README/docs/lineage assertions, and a "full audit gate"
that re-runs every prior sprint smoke. The audit-gate behavior is
obsolete (Part 6's `run-all.sh` + matrix CI replace it). The
example + docs assertions are valid present-tense invariants and
move here.

Patterns governing this part:
- `patterns/plugin-structure.md` — `examples/` and `docs/` purpose.
- `conventions.md` — "Lineage is documented honestly"; README
  credits Vibeflow + Bedrock.

## Definition of Done

1. `tests/example-project.test.sh` asserts:
   (a) `examples/greenfield-payment-service/` exists with
   `README.md`, `CLAUDE.md`, `.yoke/config.yaml`, `.yoke/prd.md`,
   `.yoke/tech-spec.md`, `.yoke/acceptance-contract.md`;
   (b) `prd.md` and `tech-spec.md` carry `Status: approved`,
   `acceptance-contract.md` carries `Status: ratified`;
   (c) example `CLAUDE.md` has `## Testing`, `## Linting`,
   `## Build` sections; (d) the contract has ≥3 BDD scenarios
   (`^### Scenario [0-9]+`) and ≥4 functional requirements
   (`^- \[ \] \*\*FR-`); (e) running
   `lib/sensors/discover-from-claude-md.sh` against the example's
   `CLAUDE.md` emits ≥2 sensors with `category: testing`.
2. `tests/docs-and-lineage.test.sh` asserts:
   (a) `docs/lineage.md` cites `github.com/pe-menezes/vibeflow` and
   `github.com/iurykrieger/claude-bedrock`; (b) `docs/lineage.md`
   contains the "ex nihilo" honesty statement;
   (c) `docs/troubleshooting.md` has sections for `Installation`,
   `Phase 1`, `Phase 4`, `Phase 5`, `Phase 6`;
   (d) `docs/architecture.md` mentions Model C;
   (e) `README.md` credits `Vibeflow` and `Bedrock` and links to
   `docs/installation.md` (or `/plugin marketplace add ...`),
   `docs/quickstart.md`, `docs/architecture.md`;
   (f) `CHANGELOG.md` has at least one `## [<version>]` heading
   matching the manifest version.
3. `bash tests/example-project.test.sh` and
   `bash tests/docs-and-lineage.test.sh` exit 0 against HEAD.
4. **Craftsmanship gate.**
   `grep -EIn 'sprint-[0-9]|Sprint [0-9]|Part [0-9]|v[0-9]+\.[0-9]+'
   tests/example-project.test.sh tests/docs-and-lineage.test.sh`
   returns nothing.
5. Both files pass `bash -n` and (if available) `shellcheck`.

## Scope

- Create `tests/example-project.test.sh`.
- Create `tests/docs-and-lineage.test.sh`.
- Both source `tests/lib/harness.sh` and call `harness::summary`.

## Anti-scope

- **No "full audit gate" that re-runs other tests.** That sprint-8
  pattern is obsolete; `run-all.sh` (Part 1) and matrix CI (Part 6)
  replace it.
- **No assertions about specific BDD scenario *content*** — only
  count.
- **No assertions about doc word counts or section ordering** —
  only presence.
- **No CHANGELOG content assertions beyond format + version match.**
- **No CI changes** (Part 6).

## Technical Decisions

- **Sensor-discovery assertion duplicates Part 4 (intentional).**
  Part 4 owns "the sensor lib emits structured output"; Part 5 owns
  "the example project has discoverable sensors". Each test fails
  for a different reason — a regression in either surfaces the right
  diagnosis.
- **Phase section list in `docs/troubleshooting.md` is hardcoded.**
  Current sprint-8 smoke checks `Installation`, `Phase 1`, `Phase 4`,
  `Phase 5`, `Phase 6` (Phase 2 / 3 not enumerated separately). This
  part preserves that exact list — restructuring the troubleshooting
  doc is out of scope.
- **README link checks are presence-only.** Hyperlink validity (HTTP
  200) is too costly for a smoke test and pulls in network deps.
- **CHANGELOG version match cross-references the manifest** rather
  than a literal — honors PRD anti-scope on version literals.

## Applicable Patterns

- `patterns/plugin-structure.md` — `examples/`, `docs/` purpose.
- `conventions.md` — "Lineage is documented honestly"; "Crediting
  Vibeflow and Bedrock in README.md is mandatory".

## Risks

- **Example-project drift.** If the example's contract is regenerated
  with fewer than 3 BDD scenarios or 4 FRs, this test fails.
  Mitigation: thresholds are loose; regeneration that drops below
  signals an example regression.
- **Troubleshooting structure refactor.** If the doc reorganizes
  away from per-phase sections, this test must adapt.
  Mitigation: failure pinpoints the exact missing section.

## Dependencies

- `.vibeflow/specs/framework-tests-rewrite-part-1.md`
