#!/usr/bin/env bash
# tests/smoke/append-runs-retired.test.sh
#
# Sensor: append-runs-retired (computational, cheap).
#
# Pins the retirement documented in
# https://github.com/iurykrieger/claude-yoke/issues/30:
# the sensor-harness-realignment PRD (PR #20, commit `4fe3cdf`)
# rejected the `runs:` field on per-sensor files but the writer of
# that history — `lib/sensors/append-runs.sh` — and its caller in
# `skills/implement/SKILL.md` step 4 stayed on disk. PR #23
# (`104b54e`) retired both. The regression-pin assertions for that
# retirement (Parts (l), (m), (n) in `tests/sensor-tiering.test.sh`)
# sit behind an early `harness::summary; exit $?` and are unreachable;
# the parent test file is also not in the CI matrix. This smoke test
# is the live pin.
#
# Coverage:
#   (A) `lib/sensors/append-runs.sh` does not exist on disk.
#   (B) `skills/implement/SKILL.md` does not invoke the retired
#       helper (no `append-runs.sh` substring anywhere in the file).
#   (C) `templates/sensor.md` frontmatter does not declare `runs:`
#       (the body comment is allowed to name the field as a legacy
#       rejection target — that is documentation, not schema).
#   (D) `templates/sensor.md` body documents `runs:` as a rejected
#       legacy field — positive control that the rejection is
#       intentional, not accidental.
#   (E) `lib/sensors/ack-sensors.sh --mode readiness` rejects a
#       fixture sensor that carries `runs:` in its frontmatter,
#       exits non-zero, and writes the documented error line on
#       stderr naming the field.
#
# References:
# - Source PRD (retirement): `2026-04-30-sensor-harness-realignment`
# - Retirement PR: #23 (`104b54e`)

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

# Watchdog (concepts/yoke-conventions): never let a hung subshell block CI.
(sleep 600 && kill -TERM $$ &) >/dev/null 2>&1

cd "$PLUGIN_ROOT"

APPEND_RUNS="$PLUGIN_ROOT/lib/sensors/append-runs.sh"
IMPLEMENT_SKILL="$PLUGIN_ROOT/skills/implement/SKILL.md"
SENSOR_TEMPLATE="$PLUGIN_ROOT/templates/sensor.md"
ACK_SENSORS="$PLUGIN_ROOT/lib/sensors/ack-sensors.sh"

# ----------------------------------------------------------------------
# (A) Helper script deleted.
# ----------------------------------------------------------------------
if [ -e "$APPEND_RUNS" ]; then
  err "(A) lib/sensors/append-runs.sh still on disk despite retirement (PR #23)"
else
  pass "(A) lib/sensors/append-runs.sh absent (writer of retired runs: history)"
fi

# ----------------------------------------------------------------------
# (B) Implement skill no longer references the retired helper.
# ----------------------------------------------------------------------
[ -f "$IMPLEMENT_SKILL" ] \
  || { err "(B) skills/implement/SKILL.md missing — cannot validate non-reference"; harness::summary; }

if grep -qF 'append-runs.sh' "$IMPLEMENT_SKILL"; then
  err "(B) skills/implement/SKILL.md still references append-runs.sh — match: $(grep -nF 'append-runs.sh' "$IMPLEMENT_SKILL" | head -3)"
else
  pass "(B) skills/implement/SKILL.md does not reference append-runs.sh"
fi

# ----------------------------------------------------------------------
# (C) Sensor template frontmatter (between the two '---' fences) does
# not declare runs:. The body comment may still name the field — that
# is documentation, asserted separately in (D).
# ----------------------------------------------------------------------
[ -f "$SENSOR_TEMPLATE" ] \
  || { err "(C) templates/sensor.md missing"; harness::summary; }

frontmatter="$(awk '
  /^---$/ { count++; if (count == 1) { capture = 1; next } else { exit } }
  capture { print }
' "$SENSOR_TEMPLATE")"

if printf '%s\n' "$frontmatter" | grep -qE '^runs:'; then
  err "(C) templates/sensor.md frontmatter declares runs: — rejected legacy field re-introduced. Frontmatter:
$frontmatter"
else
  pass "(C) templates/sensor.md frontmatter does not declare runs:"
fi

# ----------------------------------------------------------------------
# (D) Sensor template body documents runs: as a rejected legacy field.
# Positive control — the rejection is intentional, not accidental.
# ----------------------------------------------------------------------
if grep -qE 'Legacy fields .*\brruns?\b|Legacy fields .*runs:.*REJECTED|runs:.*REJECTED' "$SENSOR_TEMPLATE"; then
  pass "(D) templates/sensor.md body documents runs: as a rejected legacy field"
elif grep -qF 'runs:' "$SENSOR_TEMPLATE" && grep -qE 'REJECTED|legacy' "$SENSOR_TEMPLATE"; then
  pass "(D) templates/sensor.md body documents runs: alongside REJECTED/legacy markers"
else
  err "(D) templates/sensor.md body does not document runs: as a rejected legacy field — retirement intent is unstated"
fi

# ----------------------------------------------------------------------
# (E) ack-sensors.sh --mode readiness rejects a fixture with runs:
# in its frontmatter, exits non-zero, and emits the documented
# stderr line naming the field.
# ----------------------------------------------------------------------
[ -f "$ACK_SENSORS" ] \
  || { err "(E) lib/sensors/ack-sensors.sh missing — cannot validate runs: rejection"; harness::summary; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FIXTURE="$TMP/legacy-runs-sensor.md"
cat > "$FIXTURE" <<'YAML'
---
id: legacy-runs-sensor
type: computational
token_cost: 0
time_cost: 30
command: echo legacy
runs:
  - cycle: 1
    status: pass
---

# Legacy runs: sensor fixture

## How to run

Reproduces the legacy `runs:` array that the new template forbids.

## Known issues

None.

## Frequent errors

- legacy field: rejected by readiness validator
YAML

stderr_e=""
bash "$ACK_SENSORS" --mode readiness "$FIXTURE" >/dev/null 2>"$TMP/stderr_e"
rc_e=$?
stderr_e="$(cat "$TMP/stderr_e")"

if [ "$rc_e" -ne 0 ]; then
  pass "(E) ack-sensors --mode readiness rejects runs: with exit $rc_e"
else
  err "(E) ack-sensors --mode readiness accepted runs: (expected non-zero exit, got 0); stderr=$stderr_e"
fi

if printf '%s' "$stderr_e" | grep -qF "legacy field 'runs:' is no longer supported"; then
  pass "(E) stderr names the rejected field with documented message"
else
  err "(E) stderr does not name the rejected field — got: $stderr_e"
fi

harness::summary
