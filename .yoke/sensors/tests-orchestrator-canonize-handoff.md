---
id: tests-orchestrator-canonize-handoff
type: computational
token_cost: 0
time_cost: 30
command: bash tests/smoke/orchestrator-canonize-handoff.test.sh
---

# tests-orchestrator-canonize-handoff

Regression sensor for the Orchestrator → `/yoke:canonize` handoff
contract. Asserts that the v2.0.0 zero-argument facade contract
documented at `skills/canonize/SKILL.md` Phase 0 is honored uniformly
by the two consumer surfaces (`agents/orchestrator.md` and
`skills/implement/SKILL.md`) and that no caller-identity
discriminator (positional argument, opt-in flag, environment
variable, or wrapper subskill) has been reintroduced anywhere in the
plugin tree.

The sensor is fail-closed on any prose drift that would re-trip the
v2.0.0 hard-rejection guard at `skills/canonize/SKILL.md` Phase 0
during a `/yoke:implement` full-run termination handoff.

## How to run

Run via the value of the `command:` field above. The sensor is
computational: bash executes the literal shell command, which
performs four static checks against the post-fix tree and exits 0
when the canonize-invocation contract is coherent across the three
documented surfaces, or non-zero (reproducing the v2.0.0
hard-rejection diagnostic) when a regression is detected.

The underlying smoke test lives at
`tests/smoke/orchestrator-canonize-handoff.test.sh`. It includes the
standard internal watchdog (`sleep 600 && kill -TERM $$ &`) per the
testing convention documented in CLAUDE.md.

## Known issues

- The four static checks are grep-based; a future migration that
  legitimately introduces an alternate canonize-invocation contract
  on a separate verb (e.g. a non-Orchestrator consumer) would need
  to either add the new verb to the search-exclusion set or
  refactor the sensor's check 2 / check 3 expectations. This is
  flagged in the regression-sensor doctrine entry that supersedes
  `concepts/yoke-pattern-model-c-governance`'s caller-aware-routing
  body section.

## Frequent errors

- `regression: '--from-orchestrator' reference in consumer prose:`
  → drop every `--from-orchestrator` and `from-orchestrator`
  occurrence from `agents/orchestrator.md` and
  `skills/implement/SKILL.md`. The v2.0.0 facade contract is
  zero-argument; consumer prose must cite that contract, not
  restate a retired flag.
- `regression: env-var discriminator reintroduced:` → remove the
  `YOKE_FROM_ORCHESTRATOR` reference. Caller identity is not a
  routing input; Model C lane selection is diff-driven via the
  five-criterion cascade in
  `lib/canonical-memory/canonization-criteria.sh`.
- `regression: wrapper subskill reintroduced:` → remove the
  `canonize-from-orchestrator` reference. The v2.0.0 facade is the
  single canonize-invocation surface; wrapper subskills add a
  contract that has to be kept coherent across migrations and
  defeats the purpose of the prose-only alignment.
- `regression: zero-argument guard removed from skills/canonize/SKILL.md`
  → restore the literal abort diagnostic
  `wm: /yoke:canonize takes no arguments at v2.0.0` at
  `skills/canonize/SKILL.md` Phase 0. The canonize skill is the
  contract authority; weakening the guard there breaks every
  consumer that relies on the zero-argument shape.
