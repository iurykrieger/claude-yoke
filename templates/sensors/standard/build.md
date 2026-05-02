---
id: build
type: computational
token_cost: 0
time_cost: 120
command: <DISCOVER>
---

# build

Standard sensor — builds the host project. The `command:` field is
resolved at `/yoke:ack-sensors --mode bootstrap` time via the
discover-from chain:

  1. CLAUDE.md `## Build` section (first backticked command).
  2. package.json `scripts.build`.
  3. Makefile `build:` target.

If none of the above resolves, the sensor file is created with a
no-op `command: 'echo "build: no build system declared"; exit 0'`
so the sensor remains decidable. Edit the file by hand to
specialize for plugin-style projects (where "build" means
"directory layout matches plugin-structure pattern").

## How to run

`bash -c "$(awk '/^command:/{sub(/^command:[[:space:]]*/,""); print}' .yoke/sensors/build.md)"`

## Known issues

- Plugin-style projects often have no compile step; the no-op
  command is intentional so dependent criteria don't block on a
  build that isn't there.

## Frequent errors

- build-script-missing-set-e: passes with exit 0 even when intermediate steps fail. Audit the build script and add `set -euo pipefail` near the top.
