#!/usr/bin/env bash
# tests/smoke/placeholder-sensor-preflight.test.sh
#
# Sensor: placeholder-sensor-preflight (computational, cheap).
#
# Pins the regression documented in
# https://github.com/iurykrieger/claude-yoke/issues/29:
# `hooks/verify-acceptance.sh` used to register sensors whose
# `command:` (or `agent:`) carried a doctrinal placeholder
# (`<!-- TODO: fill -->`, `<TODO>`, `TBD`, etc.), then dispatched
# `bash -c "<placeholder-string>"` at run time. The leading binary
# (`<!--`) was never resolvable, so the dispatch returned
# `status: skip`. The convergence rule requires `pass` on every
# criterion (skip != pass), so a sprint with one such sensor exhausted
# the 8-cycle hard bound on every /yoke:implement run with no organic
# path to convergence. Observed cost during the v3.0 council dogfood:
# ~7000s wallclock and 24 dispatches per run before escalation.
#
# Coverage:
#   (A) HTML-comment placeholder on `command:` — the issue's
#       documented case (`<!-- TODO: fill -->`) — the hook exits 4
#       and stderr names both the placeholder and issue #29.
#   (B) Angle-bracketed slot markers on `command:` —
#       `<TODO>`, `<FIXME>`, `<TBD>`, `<placeholder>`, `<fill in>`,
#       `<your-...>`, `<insert-...>`, `<edit-...>` — all rejected.
#   (C) Bare-token markers as the first word of `command:` —
#       `TODO`, `FIXME`, `TBD` — rejected.
#   (D) HTML-comment placeholder on `agent:` (inferential sensors)
#       rejected with the same exit code and stderr shape.
#   (E) Negative control — a real shell command that contains the
#       substring `TODO` mid-line (e.g. `echo TODO_DONE`) is NOT a
#       placeholder and dispatches normally (status: pass).
#   (F) Negative control — the bare `id`/`type`/`command|agent`
#       wiring of an otherwise-valid sensor file dispatches without
#       triggering the placeholder branch.
#
# References:
# - Source issue: #29 (filed during v3.0 dogfood, transcript
#   `25e4a610` line 479 / agent diagnosis line 481).
# - Hook: `hooks/verify-acceptance.sh::sensor_value_is_placeholder`
#   and `load_sensor_metadata`.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

# Watchdog (concepts/yoke-conventions): never let a hung subshell block CI.
(sleep 600 && kill -TERM $$ &) >/dev/null 2>&1

cd "$PLUGIN_ROOT"

HOOK="$PLUGIN_ROOT/hooks/verify-acceptance.sh"
[ -f "$HOOK" ] || { err "hook missing at $HOOK"; harness::summary; }

# Build a temp host project where verify-acceptance.sh can resolve
# `.yoke/sensors/<id>.md` and an Acceptance Contract under
# `.yoke/acceptance-contracts/<slug>.md`. The harness boots fresh on
# every assertion to keep state isolated.
WORK_ROOT="$(mktemp -d)"
trap 'rm -rf "$WORK_ROOT"' EXIT

# Shared scaffold helpers ----------------------------------------------------
fresh_host() {
  local host="$1"
  rm -rf "$host"
  mkdir -p "$host/.yoke/sensors" "$host/.yoke/acceptance-contracts" "$host/.yoke/runtime"
  echo "$host"
}

write_sensor() {
  local host="$1" id="$2" type="$3" key="$4" value="$5"
  local path="$host/.yoke/sensors/${id}.md"
  cat > "$path" <<SENSOR
---
id: $id
type: $type
token_cost: 0
time_cost: 30
${key}: ${value}
---

# $id

## How to run

Test sensor — placeholder rejection coverage.

## Known issues

None.

## Frequent errors

- placeholder: rejected at pre-flight
SENSOR
  printf '%s' "$path"
}

write_contract() {
  local host="$1" sid="$2"
  local path="$host/.yoke/acceptance-contracts/placeholder-fixture.md"
  cat > "$path" <<CONTRACT
# Acceptance Contract — placeholder-fixture

## Use cases

### Scenario 1 — placeholder rejection

Given a sensor with a placeholder in command/agent
When verify-acceptance.sh runs against this contract
Then the hook exits non-zero before any sensor dispatch

### Validation

- **${sid}** — exercises the placeholder rejection branch.

### Criterion Scenario 1

Sensors: [${sid}]
CONTRACT
  printf '%s' "$path"
}

run_hook() {
  local host="$1" contract="$2" stderr_path="$3"
  (
    cd "$host" \
      && bash "$HOOK" "$contract" --criterion "Scenario 1"
  ) >/dev/null 2>"$stderr_path"
}

# ---------------------------------------------------------------------------
# (A) HTML-comment placeholder on command: — the documented case.
# ---------------------------------------------------------------------------
HOST_A="$(fresh_host "$WORK_ROOT/host_a")"
SP_A="$(write_sensor "$HOST_A" "ph-html-comment" "computational" "command" "<!-- TODO: fill -->")"
CT_A="$(write_contract "$HOST_A" "ph-html-comment")"
run_hook "$HOST_A" "$CT_A" "$WORK_ROOT/stderr_a"
rc_a=$?
stderr_a="$(cat "$WORK_ROOT/stderr_a")"

[ "$rc_a" -eq 4 ] \
  && pass "(A) HTML-comment placeholder on command: rejected at pre-flight (exit 4)" \
  || err "(A) expected exit 4, got $rc_a; stderr=$stderr_a"

if printf '%s' "$stderr_a" | grep -qF "is a placeholder ('<!-- TODO: fill -->')"; then
  pass "(A) stderr names the placeholder value verbatim"
else
  err "(A) stderr does not name the placeholder verbatim — got: $stderr_a"
fi

if printf '%s' "$stderr_a" | grep -qF "issue #29"; then
  pass "(A) stderr cites issue #29 for actionable hand-off"
else
  err "(A) stderr does not cite issue #29 — got: $stderr_a"
fi

# ---------------------------------------------------------------------------
# (B) Angle-bracketed slot markers on command:.
# ---------------------------------------------------------------------------
declare -a B_MARKERS=( "<TODO>" "<FIXME>" "<TBD>" "<placeholder>" "<fill in>" "<your-shell-cmd>" "<insert-cmd>" "<edit-me>" )
b_pass=0
b_fail=0
b_failed_markers=""
for marker in "${B_MARKERS[@]}"; do
  HOST_B="$(fresh_host "$WORK_ROOT/host_b")"
  safe_id="ph-bracket-$(printf '%s' "$marker" | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]')"
  SP_B="$(write_sensor "$HOST_B" "$safe_id" "computational" "command" "$marker")"
  CT_B="$(write_contract "$HOST_B" "$safe_id")"
  run_hook "$HOST_B" "$CT_B" "$WORK_ROOT/stderr_b"
  rc_b=$?
  if [ "$rc_b" -eq 4 ] && grep -qF "is a placeholder ('${marker}')" "$WORK_ROOT/stderr_b"; then
    b_pass=$((b_pass + 1))
  else
    b_fail=$((b_fail + 1))
    b_failed_markers+=" '$marker'(rc=$rc_b)"
  fi
done

if [ "$b_fail" -eq 0 ]; then
  pass "(B) angle-bracketed slot markers all rejected (${b_pass}/${#B_MARKERS[@]})"
else
  err "(B) ${b_fail}/${#B_MARKERS[@]} slot markers leaked through:${b_failed_markers}"
fi

# ---------------------------------------------------------------------------
# (C) Bare-token markers as first word of command:.
# ---------------------------------------------------------------------------
declare -a C_MARKERS=( "TODO" "TODO: fill" "FIXME later" "TBD" "TBD:" )
c_pass=0
c_fail=0
c_failed_markers=""
for marker in "${C_MARKERS[@]}"; do
  HOST_C="$(fresh_host "$WORK_ROOT/host_c")"
  safe_id="ph-bare-$(printf '%s' "$marker" | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]')"
  SP_C="$(write_sensor "$HOST_C" "$safe_id" "computational" "command" "$marker")"
  CT_C="$(write_contract "$HOST_C" "$safe_id")"
  run_hook "$HOST_C" "$CT_C" "$WORK_ROOT/stderr_c"
  rc_c=$?
  if [ "$rc_c" -eq 4 ] && grep -qF "is a placeholder ('${marker}')" "$WORK_ROOT/stderr_c"; then
    c_pass=$((c_pass + 1))
  else
    c_fail=$((c_fail + 1))
    c_failed_markers+=" '$marker'(rc=$rc_c)"
  fi
done

if [ "$c_fail" -eq 0 ]; then
  pass "(C) bare-token markers all rejected (${c_pass}/${#C_MARKERS[@]})"
else
  err "(C) ${c_fail}/${#C_MARKERS[@]} bare-token markers leaked through:${c_failed_markers}"
fi

# ---------------------------------------------------------------------------
# (D) HTML-comment placeholder on agent: (inferential).
# ---------------------------------------------------------------------------
HOST_D="$(fresh_host "$WORK_ROOT/host_d")"
SP_D="$(write_sensor "$HOST_D" "ph-inferential" "inferential" "agent" "<!-- TODO: fill -->")"
CT_D="$(write_contract "$HOST_D" "ph-inferential")"
run_hook "$HOST_D" "$CT_D" "$WORK_ROOT/stderr_d"
rc_d=$?
stderr_d="$(cat "$WORK_ROOT/stderr_d")"

[ "$rc_d" -eq 4 ] \
  && pass "(D) HTML-comment placeholder on agent: rejected at pre-flight (exit 4)" \
  || err "(D) expected exit 4, got $rc_d; stderr=$stderr_d"

if printf '%s' "$stderr_d" | grep -qF "type 'inferential' but 'agent:' is a placeholder"; then
  pass "(D) stderr names the inferential dispatch path"
else
  err "(D) stderr does not name the inferential dispatch path — got: $stderr_d"
fi

# ---------------------------------------------------------------------------
# (E) Negative control — `echo TODO_DONE` is a real command, not a
# placeholder. It must NOT trigger the placeholder branch.
# ---------------------------------------------------------------------------
HOST_E="$(fresh_host "$WORK_ROOT/host_e")"
SP_E="$(write_sensor "$HOST_E" "ph-negative-substring" "computational" "command" "echo TODO_DONE")"
CT_E="$(write_contract "$HOST_E" "ph-negative-substring")"
run_hook "$HOST_E" "$CT_E" "$WORK_ROOT/stderr_e"
rc_e=$?
stderr_e="$(cat "$WORK_ROOT/stderr_e")"

if [ "$rc_e" -ne 4 ] || ! printf '%s' "$stderr_e" | grep -qF "is a placeholder"; then
  pass "(E) negative control 'echo TODO_DONE' does not trip placeholder branch (exit $rc_e)"
else
  err "(E) negative control 'echo TODO_DONE' tripped placeholder branch — got: $stderr_e"
fi

# ---------------------------------------------------------------------------
# (F) Negative control — a fully-valid sensor (real shell command) is
# not flagged.
# ---------------------------------------------------------------------------
HOST_F="$(fresh_host "$WORK_ROOT/host_f")"
SP_F="$(write_sensor "$HOST_F" "ph-negative-valid" "computational" "command" "true")"
CT_F="$(write_contract "$HOST_F" "ph-negative-valid")"
run_hook "$HOST_F" "$CT_F" "$WORK_ROOT/stderr_f"
rc_f=$?
stderr_f="$(cat "$WORK_ROOT/stderr_f")"

if ! printf '%s' "$stderr_f" | grep -qF "is a placeholder"; then
  pass "(F) negative control 'true' does not trip placeholder branch (exit $rc_f)"
else
  err "(F) negative control 'true' tripped placeholder branch — got: $stderr_f"
fi

harness::summary
