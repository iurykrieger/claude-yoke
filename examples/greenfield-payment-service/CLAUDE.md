# CLAUDE.md

> Project guidance for Claude Code. The `## Testing`, `## Linting`, and
> `## Build` sections below follow Yoke's sensor-discovery convention —
> the Validator extracts the first backticked command from each bullet
> via `lib/sensors/discover-from-claude-md.sh`.

## Project overview

**greenfield-payment-service** — a small Node.js / TypeScript service
that reverses a payment given a `tx_id`. New project, no production
deployment yet. Used as the Yoke v1.0 reference example.

## Testing
- `npm test` — run unit tests (Vitest)
- `npm run test:integration` — run integration tests against the local stub gateway
- `npm run test:contract` — run contract tests against the public API schema

## Linting
- `npm run lint` — run ESLint over `src/`
- `npm run lint:types` — run `tsc --noEmit` for strict type checking

## Build
- `npm run build` — production TypeScript build (`tsc -p tsconfig.build.json`)

## Yoke

This project uses [Yoke](https://github.com/iurykrieger/yoke) for
governed AI-agent development. See `.yoke/` for the current task's
PRD / Tech Spec / Acceptance Contract.

To start a new task, run `/yoke:discover "<your idea>"`. Other commands
in the flow:

- `/yoke:tech-spec` — Phase 2
- `/yoke:acceptance-contract` — Phase 3 (binding)
- `/yoke:implement` — Phase 4 (adversarial loop with hard bounds)
- `/yoke:canonize` — Phase 5 (Model C — low/medium auto, high/regulatory sync)
- `/yoke:drift-sense` — Phase 6 (continuous; runs daily via Actions)
- `/yoke:ask "<term>"` — mediated canonical-memory query
- `/yoke:status` — current task state
