# CLAUDE.md

> Project guidance for Claude Code.

## Testing
<!-- Replace with your project's test commands. Yoke's Validator parses this section to discover available sensors. -->
- `npm test` — run unit tests
- `npm run test:integration` — run integration tests

## Linting
<!-- Replace with your project's linters. -->
- `npm run lint` — run linter

## Build
<!-- Replace with your project's build commands. -->
- `npm run build` — production build

## Yoke

This project uses [Yoke](https://github.com/iurykrieger/yoke) for governed
AI-agent development. Run `/yoke:discover "<your idea>"` to start a new task.

### Phase 3 — Acceptance Criteria

The Phase 3 binding artifact (post v4.0.0) is the **Acceptance
Criteria document** at `.yoke/acceptance-criteria/<slug>.md`, organised
as User Stories → Definition of Done → Acceptance Criteria → Sensor
pool. Authored through the Senior-QA grill in
`/yoke:acceptance-criteria` (replacing the v3.x `/yoke:acceptance-contract`
verb).

- **Definition of Done** — single binary checklist per User Story;
  defines when implementation is *finished*.
- **Acceptance Criteria** — multiple observable QA conditions per
  User Story; given the implementation is done, define when the
  work is *acceptable* in quality terms.
- **Sensor pool** — flat list of sensor IDs relevant to this task;
  Sr QA and Sr Staff pick which pool members gate which Acceptance
  Criterion at Phase 4 runtime. No mandatory/complementary tags at
  authoring time.

### Setup prerequisites

- Yoke v4.0.0 requires a canonical-memory provider plugin to be installed
  (the reference implementation is `claude-bedrock`). `/yoke:bootstrap`
  picks the provider interactively or via `--provider <name>`. See
  `docs/canonical-memory-setup.md` in the Yoke plugin repo for
  substrate configuration, `docs/migration-v1-to-v2.md` if you are
  upgrading from a v1.x project, and `docs/migration-v3-to-v4.md` if
  you are upgrading from a v3.x project.

### Querying canonical memory

- Read with `/yoke:search-canonical-memory "<your question>"`. The
  facade dispatches to the active provider (Bedrock by default) and
  returns the response verbatim. Use it to retrieve patterns,
  decisions, and policies before proposing a change.
- Write with `/yoke:canonize` after a task converges. The facade
  hands the converged working-memory packet to the active provider's
  canonize skill, which applies Model C governance (auto-apply /
  notify-and-apply / synchronous ratification by impact class).
