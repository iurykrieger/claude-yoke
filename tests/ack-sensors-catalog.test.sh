#!/bin/bash
# tests/ack-sensors-catalog.test.sh
#
# Smoke test for /yoke:ack-sensors — catalog mode + mode-dispatch
# error paths + SKILL.md compliance.
#
# Originally validated DoD #1–#6 of
# `.vibeflow/specs/ack-sensors-skill-part-1.md`. Readiness coverage
# (DoD #2) was rewritten in `sensor-cost-tiering` Part 2 — the
# binary-on-PATH check was replaced by per-sensor-file existence /
# frontmatter checks against `.yoke/sensors/<id>.md`. Comprehensive
# readiness + upsert assertions for the new behavior live in
# `tests/sensor-tiering.test.sh`. This file now covers:
#   - deterministic sorted catalog YAML
#   - empty-discovery envelope
#   - mode-dispatch error paths (missing contract, missing arg,
#     unknown --mode value)
#   - SKILL.md frontmatter + structured-output compliance

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="${PLUGIN_ROOT}/lib/sensors/ack-sensors.sh"
SKILL="${PLUGIN_ROOT}/skills/ack-sensors/SKILL.md"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- ack-sensors Part 1 smoke ---"

# 0. Helper + skill exist and are runnable
[ -f "$HELPER" ] || { err "missing helper: $HELPER"; exit 1; }
[ -f "$SKILL" ]  || { err "missing skill: $SKILL"; exit 1; }
[ -x "$HELPER" ] && pass "helper executable" || err "helper not executable"

# Build a temp host project with a fixture CLAUDE.md.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "${tmp}/CLAUDE.md" <<'EOF'
# Fixture host project

## Build
- `make build` — build everything

## Linting
- `npm run lint` — eslint pass

## Testing
- `npm test` — run unit tests
- `pytest tests/` — run python tests

## Other
Some prose that should be ignored.
EOF

# ---------------------------------------------------------------------------
# DoD #1 — deterministic sorted catalog YAML
# ---------------------------------------------------------------------------
out1="$(cd "$tmp" && bash "$HELPER")"
out2="$(cd "$tmp" && bash "$HELPER" --mode catalog)"
out3="$(cd "$tmp" && bash "$HELPER" --mode catalog)"

if [ "$out1" = "$out2" ]; then
  pass "default mode is catalog"
else
  err "default mode differs from --mode catalog"
fi

if [ "$out2" = "$out3" ]; then
  pass "catalog output is byte-identical across consecutive invocations"
else
  err "catalog output differs across invocations (non-deterministic)"
fi

# Expected sort order under LC_ALL=C:
# (build, claude-md, "make build")
# (linting, claude-md, "npm run lint")
# (testing, claude-md, "npm test")
# (testing, claude-md, "pytest tests/")
expected_catalog=$'sensors:\n  - category: build\n    command: "make build"\n    source: claude-md\n  - category: linting\n    command: "npm run lint"\n    source: claude-md\n  - category: testing\n    command: "npm test"\n    source: claude-md\n  - category: testing\n    command: "pytest tests/"\n    source: claude-md\nnotes: []'

if [ "$out2" = "$expected_catalog" ]; then
  pass "catalog YAML matches expected sorted output"
else
  err "catalog YAML mismatch. expected:"$'\n'"${expected_catalog}"$'\n'"got:"$'\n'"${out2}"
fi

# Both required keys present
echo "$out2" | grep -q '^sensors:' && pass "catalog has sensors: key" || err "catalog missing sensors:"
echo "$out2" | grep -q '^notes:' && pass "catalog has notes: key" || err "catalog missing notes:"

# ---------------------------------------------------------------------------
# DoD #3 — empty-discovery envelope when CLAUDE.md is missing
# ---------------------------------------------------------------------------
empty_dir="$(mktemp -d)"
out_empty="$(cd "$empty_dir" && bash "$HELPER")"
rm -rf "$empty_dir"

echo "$out_empty" | grep -q '^sensors: \[\]' && pass "missing CLAUDE.md → sensors: []" || err "missing CLAUDE.md did not produce empty sensors:"
echo "$out_empty" | grep -q '^notes:' && pass "missing CLAUDE.md → notes: present" || err "missing CLAUDE.md did not include notes:"

# ---------------------------------------------------------------------------
# Readiness coverage moved to tests/sensor-tiering.test.sh (sensor-cost-
# tiering Part 2) — readiness now checks `.yoke/sensors/<id>.md`
# files instead of binary-on-PATH. The mode-dispatch error paths
# below still apply and are exercised here.
# ---------------------------------------------------------------------------

# Missing contract path → exit 3
set +e
bash "$HELPER" --mode readiness "/nonexistent/path/to/contract.md" >/dev/null 2>&1
no_contract_code=$?
set -e
if [ "$no_contract_code" -eq 3 ]; then
  pass "missing contract → exit 3"
else
  err "missing contract → exit ${no_contract_code} (expected 3)"
fi

# Readiness without contract path → exit 2 (usage error)
set +e
bash "$HELPER" --mode readiness >/dev/null 2>&1
usage_code=$?
set -e
if [ "$usage_code" -eq 2 ]; then
  pass "readiness without contract → exit 2 (usage error)"
else
  err "readiness without contract → exit ${usage_code} (expected 2)"
fi

# Bad mode → exit 2
set +e
bash "$HELPER" --mode bogus >/dev/null 2>&1
bad_mode_code=$?
set -e
if [ "$bad_mode_code" -eq 2 ]; then
  pass "unknown --mode → exit 2"
else
  err "unknown --mode → exit ${bad_mode_code} (expected 2)"
fi

# ---------------------------------------------------------------------------
# DoD #6 — SKILL.md frontmatter compliance: allowed-tools = Bash, Read only
# ---------------------------------------------------------------------------
allowed_line="$(awk '/^allowed-tools:/{print; exit}' "$SKILL" || true)"
if [ -z "$allowed_line" ]; then
  err "SKILL.md missing allowed-tools field"
else
  if echo "$allowed_line" | grep -qw 'Task'; then
    err "SKILL.md allowed-tools includes Task — must be deterministic-only"
  else
    pass "SKILL.md allowed-tools excludes Task"
  fi
  if echo "$allowed_line" | grep -qw 'Agent'; then
    err "SKILL.md allowed-tools includes Agent — must be deterministic-only"
  else
    pass "SKILL.md allowed-tools excludes Agent"
  fi
  if echo "$allowed_line" | grep -qw 'Bash'; then
    pass "SKILL.md allowed-tools includes Bash"
  else
    err "SKILL.md allowed-tools missing Bash"
  fi
  if echo "$allowed_line" | grep -qw 'Read'; then
    pass "SKILL.md allowed-tools includes Read"
  else
    err "SKILL.md allowed-tools missing Read"
  fi
fi

# Frontmatter has name + description
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$SKILL" \
  && pass "SKILL.md frontmatter has name and description" \
  || err "SKILL.md frontmatter missing name or description"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "--- ack-sensors Part 1 smoke: $((fail == 0 ? 0 : fail)) failure(s) ---"
exit "$fail"
