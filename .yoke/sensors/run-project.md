---
id: run-project
type: computational
token_cost: 0
time_cost: 60
command: echo "run: not applicable for plugin"; exit 0
---

# run-project

Standard sensor — runs the host project end-to-end. The `command:`
field is resolved at `/yoke:ack-sensors --mode bootstrap` time via
the discover-from chain:

  1. CLAUDE.md `## Run` / `## Running` / `## How to run` section
     (first backticked command).
  2. package.json `scripts.start` or `scripts.dev`.
  3. Makefile `run:` or `start:` target.
  4. Fallback: `find tests -name "*smoke*.test.sh" -exec bash {} +`
     (smoke-runner stand-in).

Plugin-style projects (no runnable artifact) get the no-op
`echo "run: not applicable for plugin"; exit 0`. Specialize by hand
when the project has a runnable surface (CLI, daemon, service).

## How to run

`bash -c "$(awk '/^command:/{sub(/^command:[[:space:]]*/,""); print}' .yoke/sensors/run-project.md)"`

For long-running projects, the wrapper SHOULD background the
process and probe a readiness signal (HTTP 200, `--version` exit 0)
within `time_cost`, not block on the full run.

## Known issues

- Plugin / library projects: no `start` semantics; the no-op default
  is intentional. The criterion gating run-project for those
  projects must be a fixture-driven smoke, not the full runtime.
- Daemon-style projects: the sensor wrapper must fork + probe
  readiness, then kill the child. A naked `npm start` will hang the
  cycle.

## Frequent errors

- sensor-blocks-cycle-waiting-on-server: wrap with `timeout` and a readiness probe such as `curl -f http://localhost:<port>/health`.
- run-target-depends-on-env-vars-not-set-in-ci: declare them in CLAUDE.md `## Environment` and have the wrapper assert presence.
