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

### Setup prerequisites

- Yoke v2.0.0 requires a canonical-memory provider plugin to be installed
  (the reference implementation is `claude-bedrock`). `/yoke:bootstrap`
  picks the provider interactively or via `--provider <name>`. See
  `docs/canonical-memory-setup.md` in the Yoke plugin repo for
  substrate configuration and `docs/migration-v1-to-v2.md` if you are
  upgrading from a v1.x project.

### Querying canonical memory

- Read with `/yoke:search-canonical-memory "<your question>"`. The
  facade dispatches to the active provider (Bedrock by default) and
  returns the response verbatim. Use it to retrieve patterns,
  decisions, and policies before proposing a change.
- Write with `/yoke:canonize` after a task converges. The facade
  hands the converged working-memory packet to the active provider's
  canonize skill, which applies Model C governance (auto-apply /
  notify-and-apply / synchronous ratification by impact class).
