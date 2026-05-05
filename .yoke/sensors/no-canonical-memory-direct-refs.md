---
id: no-canonical-memory-direct-refs
type: computational
token_cost: 0
time_cost: 30
command: bash lib/sensors/no-canonical-memory-direct-refs.sh
---

# no-canonical-memory-direct-refs

Structural pure-bash sensor that asserts the v2.0.0 facade rule on the
`lib/sensors/` surface: zero direct references to canonical-memory
helpers extracted to the `claude-bedrock` peer plugin. Mirrors the
`no-vibeflow-refs` shape (`yoke-decision-2026-04-27-bidirectional-invariant-sensor-pattern`)
and is enforced via runtime textual scan over `lib/sensors/*.sh` plus
self-exclusion of the sensor's own file. Produced by `/yoke:fix #50`.

## How to run

`bash lib/sensors/no-canonical-memory-direct-refs.sh`

Optional `--scan-dir <dir>` overrides the default scan target
(`lib/sensors/`). Exits 0 silent on success; exits 1 with a structured
YAML violation block per match on stdout and a diagnostic summary on
stderr; exits 2 on environmental causes (scan-dir missing, unknown
flag).

## Known issues

- Exact-textual matching only — references arriving via dynamic `eval`
  or variable indirection (e.g., `local d="lib/canonical-memory";
  "$d/registry.sh"`) are not flagged. Anti-pattern by design per
  `yoke-decision-2026-04-27-bidirectional-invariant-sensor-pattern`
  (LLM-judged structural invariant rejected on cost / reproducibility
  grounds).
- Scope is `lib/sensors/` only. Forbidden references introduced
  elsewhere in the framework tree (`skills/`, `hooks/`, `agents/`)
  are out of this sensor's scope; broader coverage belongs to
  `lib/sensors/no-vibeflow-refs.sh`'s framework-clean counterpart.

## Frequent errors

- legacy-source-line: replace `source lib/canonical-memory/<X>.sh` with a dispatch through `/yoke:search-canonical-memory` or remove the dependency entirely; only `resolve-provider.sh` survives under that directory at v2.0.0.
- comment-leak: even commented-out references trip the scan because they leak stale doctrine into reader expectations; rewrite or remove the comment to describe the post-v2.0.0 facade contract.
- self-pattern-leak: the sensor's own forbidden-basename list MUST stay constructed from string parts so the source body never contains a literal `lib/canonical-memory/<forbidden>.sh` token; the runtime concatenation in `lib/sensors/no-canonical-memory-direct-refs.sh` is what breaks the self-reference paradox.
