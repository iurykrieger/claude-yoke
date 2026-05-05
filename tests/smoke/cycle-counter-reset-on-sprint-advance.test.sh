#!/usr/bin/env bash
# tests/smoke/cycle-counter-reset-on-sprint-advance.test.sh
#
# Sensor: cycle-counter-reset-on-sprint-advance (computational, cheap).
#
# Pins the regression captured at
# .yoke/fixes/2026-05-05-cycle-counter-reset-on-sprint-advance.md:
# `hooks/check-hard-bounds.sh` reads `.yoke/runtime/.cycle-counter` and
# enforces a ≤ 8-cycles-per-sprint bound, but no code path zeroes that
# file on sprint advance. The fix introduces a deterministic primitive
# `wm_reset_cycle_counter` in `lib/working-memory/paths.sh`. This test
# pins its file-side contract.
#
# Coverage (US-004 of
# .yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md):
#   (A) AC-001-1: helper called when runtime dir + .cycle-counter absent
#       → file exists afterwards with content exactly `0` (no newline).
#   (B) AC-001-2: helper is idempotent — file already at `0` stays at `0`.
#   (C) AC-001-3: helper called when file contains `7` overwrites it to
#       `0`. The seed of `7` (non-zero) is the AC-004-4 anti-coincidence
#       guard: a coincidentally-zero counter cannot make this case pass.
#   (D) AC-001-4: helper does NOT write to `progress.md` and does NOT
#       create any file under `.yoke/runtime/` other than `.cycle-counter`.
#
# Test isolation strategy: `WM_RUNTIME_DIR` inside `paths.sh` is `readonly`
# and resolves to a path relative to `.yoke` (the working directory). The
# test creates a temporary scratch dir via `mktemp -d`, `cd`s into it,
# and sources `paths.sh` from there so all `.yoke/...` writes land in the
# scratch dir — never the worktree's actual `.yoke/runtime/`.
#
# References:
# - Fix-spec: .yoke/fixes/2026-05-05-cycle-counter-reset-on-sprint-advance.md
# - Tech Spec: .yoke/specs/2026-05-05-cycle-counter-reset-on-sprint-advance.md
# - Acceptance Criteria: .yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md
# - CLAUDE.md :: ## Testing — internal watchdog convention.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

# Watchdog (CLAUDE.md :: ## Testing): never let a hung subshell block CI.
# Spawn the killer in the background of the current shell so $! resolves to
# its PID; redirect IO so its lifetime does not pollute the test stream.
sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
disown "$WATCHDOG_PID" 2>/dev/null || true

# Resolve the path helper to source — this is the binding under test.
PATHS_SH="$PLUGIN_ROOT/lib/working-memory/paths.sh"
[ -f "$PATHS_SH" ] || { err "paths.sh missing at $PATHS_SH"; harness::summary; }

# Isolated scratch dir so writes never escape into the worktree.
SCRATCH="$(mktemp -d)"
trap 'kill -TERM '"$WATCHDOG_PID"' 2>/dev/null || true; rm -rf "'"$SCRATCH"'"' EXIT

cd "$SCRATCH"

# Source paths.sh from inside the scratch dir so WM_RUNTIME_DIR resolves
# to "$SCRATCH/.yoke/runtime" via its relative `.yoke/runtime` value.
# shellcheck source=lib/working-memory/paths.sh
source "$PATHS_SH"

EXPECTED_FILE="$SCRATCH/.yoke/runtime/.cycle-counter"
EXPECTED_DIR="$SCRATCH/.yoke/runtime"

# ----------------------------------------------------------------------
# (A) AC-001-1 — runtime dir + .cycle-counter absent → helper creates
#     the file with content exactly `0`.
# ----------------------------------------------------------------------

# Pre-condition: scratch is fresh; nothing under .yoke/.
[ ! -e "$EXPECTED_DIR" ] || err "(A) precondition: $EXPECTED_DIR should not exist on fresh scratch"

if wm_reset_cycle_counter; then
    pass "(A) wm_reset_cycle_counter exits 0 on absent runtime dir"
else
    err "(A) wm_reset_cycle_counter exited non-zero on absent runtime dir"
fi

if [ -f "$EXPECTED_FILE" ]; then
    pass "(A) $EXPECTED_FILE exists after helper call"
else
    err "(A) $EXPECTED_FILE missing after helper call"
fi

actual_content="$(cat "$EXPECTED_FILE" 2>/dev/null)"
if [ "$actual_content" = "0" ]; then
    pass "(A) .cycle-counter content is exactly '0' (no trailing newline)"
else
    err "(A) .cycle-counter content is '$actual_content', expected '0'"
fi

# Stricter byte check — the contract is "byte 0, no trailing newline".
actual_size="$(wc -c < "$EXPECTED_FILE" | tr -d ' ')"
if [ "$actual_size" = "1" ]; then
    pass "(A) .cycle-counter is exactly 1 byte (no trailing newline)"
else
    err "(A) .cycle-counter is $actual_size bytes, expected 1"
fi

# ----------------------------------------------------------------------
# (B) AC-001-2 — file already at `0` → helper leaves it at `0`
#     (idempotent).
# ----------------------------------------------------------------------

# Seed the file at "0" explicitly (the (A) state is already "0", but
# we re-seed to make this case independent of (A)'s post-state).
printf '0' > "$EXPECTED_FILE"

if wm_reset_cycle_counter; then
    pass "(B) wm_reset_cycle_counter exits 0 on file already at '0'"
else
    err "(B) wm_reset_cycle_counter exited non-zero on file already at '0'"
fi

actual_content="$(cat "$EXPECTED_FILE" 2>/dev/null)"
if [ "$actual_content" = "0" ]; then
    pass "(B) .cycle-counter still reads '0' after idempotent call"
else
    err "(B) .cycle-counter is '$actual_content', expected '0'"
fi

# ----------------------------------------------------------------------
# (C) AC-001-3 + AC-004-4 — file contains '7' (non-zero seed,
#     anti-coincidence guard) → helper overwrites to '0'.
# ----------------------------------------------------------------------

# Seed a non-zero value so a coincidentally-zero counter cannot hide a
# missing helper invocation. AC-004-4 ratifies this seed.
printf '7' > "$EXPECTED_FILE"

# Sanity-check the seed actually landed.
seeded="$(cat "$EXPECTED_FILE" 2>/dev/null)"
if [ "$seeded" = "7" ]; then
    pass "(C) anti-coincidence seed: .cycle-counter primed to '7' before helper"
else
    err "(C) anti-coincidence seed failed: .cycle-counter is '$seeded', expected '7'"
fi

if wm_reset_cycle_counter; then
    pass "(C) wm_reset_cycle_counter exits 0 on non-zero seed"
else
    err "(C) wm_reset_cycle_counter exited non-zero on non-zero seed"
fi

actual_content="$(cat "$EXPECTED_FILE" 2>/dev/null)"
if [ "$actual_content" = "0" ]; then
    pass "(C) .cycle-counter overwritten from '7' to '0'"
else
    err "(C) .cycle-counter is '$actual_content', expected '0' after overwrite"
fi

# ----------------------------------------------------------------------
# (D) AC-001-4 — helper writes only .cycle-counter under runtime dir.
#     No progress.md, no other artifact.
# ----------------------------------------------------------------------

# After all calls above, .yoke/runtime/ should contain exactly one entry:
# the .cycle-counter file. Anything else is a contract violation.
runtime_entries="$(find "$EXPECTED_DIR" -mindepth 1 -maxdepth 1 | sort)"
expected_entries="$EXPECTED_DIR/.cycle-counter"

if [ "$runtime_entries" = "$expected_entries" ]; then
    pass "(D) runtime dir contains only .cycle-counter (no spurious writes)"
else
    err "(D) runtime dir contains unexpected entries: $runtime_entries"
fi

# Belt-and-suspenders: progress.md must NOT exist.
if [ ! -e "$EXPECTED_DIR/progress.md" ]; then
    pass "(D) helper did not write progress.md"
else
    err "(D) helper wrote progress.md (anti-scope violation)"
fi

# Belt-and-suspenders: no .snapshots/, no .judge-verdicts/, no cycles/.
for forbidden in .snapshots .judge-verdicts cycles .trigger4-packet.yaml; do
    if [ -e "$EXPECTED_DIR/$forbidden" ]; then
        err "(D) helper created forbidden artifact: $forbidden"
    fi
done
pass "(D) no .snapshots/, .judge-verdicts/, cycles/, or .trigger4-packet.yaml created"

harness::summary
