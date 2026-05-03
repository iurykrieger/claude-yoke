#!/usr/bin/env bash
# shellcheck shell=bash
#
# parse-inputs.test.sh — Sprint 02 / Task t03 happy-path unit test
# (US-003 DoD bullet 3 + AC-003-2).
#
# Asserts that `lib/generate-sprints/parse-inputs.sh` correctly walks
# the binding Acceptance Criteria file under `.yoke/acceptance-criteria/`
# and emits a JSON payload whose top-level shape matches the contract
# in `parse-inputs.sh`'s header docs:
#
#   - `user_stories[*].id` matches `^US-[0-9]{3}$`
#   - `user_stories` length equals the count of `### US-` headings in
#     the input file
#   - every user story carries a non-empty `dod` array AND a non-empty
#     `acceptance_criteria` array
#   - `functional_requirements[*].id` matches `^FR-[0-9]+$`
#   - `sensor_pool` is a flat array of sensor IDs
#
# Also asserts that `parse_spec_architecture` against the binding spec
# emits a JSON object with non-empty `objective` and a non-empty
# `contracts` array.
#
# This is a happy-path test (Sr Eng's lane). Negative-path coverage
# (malformed UC block, legacy UC-N shape rejection) is Sr QA's lane —
# Sr QA emits the contract-anchored acceptance test under
# tests/acceptance/<contract-slug>/.
#
# Test contract:
#   - exit 0 with a `PASS:` line on success.
#   - exit non-zero with `wm: parse-inputs violation:`-prefixed stderr
#     naming the failed assertion otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: parse-inputs violation: %s\n' "$1" >&2
  exit 1
}

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/parse-inputs.sh"

AC_PATH="${REPO_ROOT}/.yoke/acceptance-criteria/2026-05-03-generate-sprints-skill.md"
SPEC_PATH="${REPO_ROOT}/.yoke/specs/2026-05-03-generate-sprints-skill.md"

[[ -f "$AC_PATH" ]]   || violation "AC fixture not found at $AC_PATH"
[[ -f "$SPEC_PATH" ]] || violation "Spec fixture not found at $SPEC_PATH"

# --- parse_acceptance_criteria happy path ----------------------------------

# Stage the parser output to a temp file so subsequent shape checks
# can read stdin freely without colliding with heredoc-passed
# Python programs.
AC_JSON_FILE="$(mktemp)"
trap 'rm -f "$AC_JSON_FILE"' EXIT

parse_acceptance_criteria "$AC_PATH" > "$AC_JSON_FILE" \
  || violation "parse_acceptance_criteria exited non-zero against the binding AC"

# Validate JSON.
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$AC_JSON_FILE" \
  || violation "parse_acceptance_criteria stdout is not valid JSON"

# US count parity with the file's `### US-` heading count.
EXPECTED_US_COUNT="$(grep -cE '^### US-[0-9]{3}' "$AC_PATH" || true)"
ACTUAL_US_COUNT="$(python3 -c '
import json, sys
print(len(json.load(open(sys.argv[1])).get("user_stories", [])))
' "$AC_JSON_FILE")"
[[ "$ACTUAL_US_COUNT" == "$EXPECTED_US_COUNT" ]] \
  || violation "US count mismatch: file has $EXPECTED_US_COUNT '### US-' headings, parser emitted $ACTUAL_US_COUNT user stories"

# Every US.id matches `^US-[0-9]{3}$`; every US has non-empty dod + ac arrays.
python3 - "$AC_JSON_FILE" <<'PY' \
  || violation "user_stories shape check failed"
import json, re, sys
data = json.load(open(sys.argv[1]))
us_id_re = re.compile(r"^US-\d{3}$")
ac_id_re = re.compile(r"^AC-\d{3}-\d+$")
for us in data.get("user_stories", []):
    assert us_id_re.match(us["id"]), f"bad US id: {us['id']!r}"
    assert isinstance(us["dod"], list) and us["dod"], f"empty dod for {us['id']}"
    assert isinstance(us["acceptance_criteria"], list) and us["acceptance_criteria"], \
        f"empty acceptance_criteria for {us['id']}"
    for ac in us["acceptance_criteria"]:
        assert ac_id_re.match(ac["id"]), f"bad AC id: {ac['id']!r}"
PY

# Functional requirements shape (FR-N).
python3 - "$AC_JSON_FILE" <<'PY' \
  || violation "functional_requirements shape check failed"
import json, re, sys
data = json.load(open(sys.argv[1]))
fr_id_re = re.compile(r"^FR-\d+$")
frs = data.get("functional_requirements", [])
assert isinstance(frs, list), "functional_requirements is not a list"
# The binding AC carries multiple FRs; the parser must capture at least one.
assert len(frs) >= 1, "no functional_requirements parsed"
for fr in frs:
    assert fr_id_re.match(fr["id"]), f"bad FR id: {fr['id']!r}"
    assert fr.get("text"), f"empty FR text for {fr['id']}"
PY

# Sensor pool shape (flat array of sensor IDs).
python3 - "$AC_JSON_FILE" <<'PY' \
  || violation "sensor_pool shape check failed"
import json, re, sys
data = json.load(open(sys.argv[1]))
sensors = data.get("sensor_pool", [])
assert isinstance(sensors, list), "sensor_pool is not a list"
assert len(sensors) >= 1, "no sensors parsed from '## Sensor pool'"
sensor_id_re = re.compile(r"^[a-z0-9][a-z0-9_.-]{0,63}$")
for sid in sensors:
    assert sensor_id_re.match(sid), f"bad sensor id: {sid!r}"
PY

# --- parse_spec_architecture happy path ------------------------------------

SPEC_JSON_FILE="$(mktemp)"
trap 'rm -f "$AC_JSON_FILE" "$SPEC_JSON_FILE"' EXIT

parse_spec_architecture "$SPEC_PATH" > "$SPEC_JSON_FILE" \
  || violation "parse_spec_architecture exited non-zero against the binding spec"

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SPEC_JSON_FILE" \
  || violation "parse_spec_architecture stdout is not valid JSON"

python3 - "$SPEC_JSON_FILE" <<'PY' \
  || violation "spec architecture shape check failed"
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("objective"), "empty objective"
assert isinstance(data.get("contracts", []), list), "contracts is not a list"
assert len(data.get("contracts", [])) >= 1, "no contracts parsed"
deps = data.get("dependencies", {})
assert isinstance(deps, dict), "dependencies is not a dict"
for key in ("external_services", "internal_prior_work", "cross_team_coordination"):
    assert key in deps, f"missing dependencies.{key}"
    assert isinstance(deps[key], list), f"dependencies.{key} is not a list"
PY

CONTRACTS_COUNT="$(python3 -c '
import json, sys
print(len(json.load(open(sys.argv[1])).get("contracts", [])))
' "$SPEC_JSON_FILE")"

printf 'PASS: parse-inputs happy-path US=%s contracts=%s\n' \
  "$ACTUAL_US_COUNT" \
  "$CONTRACTS_COUNT"
exit 0
