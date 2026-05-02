---
id: lint
type: computational
token_cost: 0
time_cost: 30
command: <DISCOVER>
---

# lint

Standard sensor — runs the host project's linter. The `command:`
field is resolved at `/yoke:ack-sensors --mode bootstrap` time via
the discover-from chain:

  1. CLAUDE.md `## Linting` section (first backticked command).
  2. package.json `scripts.lint`.
  3. Makefile `lint:` target.
  4. Fallback: `shellcheck` against `lib/` + `hooks/` + `scripts/`.

If none of the above resolves, the sensor file is created with a
no-op `command: 'echo "lint: no linter declared"; exit 0'` so the
sensor remains decidable. Edit the file by hand to specialize.

## How to run

`bash -c "$(awk '/^command:/{sub(/^command:[[:space:]]*/,""); print}' .yoke/sensors/lint.md)"`

## Known issues

- shellcheck not installed: the fallback command short-circuits
  via `command -v shellcheck >/dev/null 2>&1 || exit 0`.

## Frequent errors

- shellcheck-false-positive-on-bash-4-syntax: refine the SC code via `# shellcheck disable=SC<code>` at the call site.
