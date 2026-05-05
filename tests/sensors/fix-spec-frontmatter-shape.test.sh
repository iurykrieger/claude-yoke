#!/usr/bin/env bash
# tests/sensors/fix-spec-frontmatter-shape.test.sh — CI gate for the
# mandatory `scope_caution:` frontmatter field on every fix-spec under
# .yoke/fixes/.
#
# Walks every .yoke/fixes/<slug>.md (when present) and asserts each
# carries the mandatory `scope_caution:` key in its frontmatter with
# one of the documented values:
#   <empty string> | component-breadth | contract-shape | trigger-specificity | surface-containment
#
# templates/fix.md is also a fix-spec-shaped artifact in repo space —
# but it intentionally carries the documented value space inline (e.g.
# "scope_caution: <empty | component-breadth | …>") so it is exempt
# from this sensor. The sensor walks `.yoke/fixes/` only — repo-level
# templates are not in scope.
#
# Source PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-6a).
# Binding Acceptance Criteria:
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
# (AC-002-3 — every fix-spec carries the scope_caution: key in
# frontmatter).
#
# Structured-sensor-output contract (per concepts/yoke-pattern-sensors):
# every failure prints (a) the offending fix-spec path, (b) the
# violation kind, (c) the corrective action.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FIXES_DIR=".yoke/fixes"

# Documented value space for `scope_caution:`. The empty string is a
# valid value (4/4 narrowness proxies passed). Order matters only for
# the human-facing error message.
ALLOWED_VALUES=(
  ""
  "component-breadth"
  "contract-shape"
  "trigger-specificity"
  "surface-containment"
)

FAIL=0
CHECKED=0

fail() {
  echo "FAIL: $*" >&2
  FAIL=1
}

pass() {
  echo "PASS: $*"
}

# Extract the value (or empty string) of a frontmatter-style field
# `> Status: ...` or `> scope_caution: ...` from the artifact's body.
# Returns:
#   0 + prints the value (possibly empty after trim) when the key is found
#   1 when the key is absent
extract_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    BEGIN { found = 0 }
    {
      # Match "> <field>: <value>" with optional surrounding whitespace.
      pat = "^>[[:space:]]*" field "[[:space:]]*:"
      if ($0 ~ pat) {
        sub(pat, "")
        sub(/^[[:space:]]+/, "")
        sub(/[[:space:]]+$/, "")
        print
        found = 1
        exit
      }
    }
    END { exit (found ? 0 : 1) }
  ' "$file"
}

is_allowed_value() {
  local v="$1"
  local allowed
  for allowed in "${ALLOWED_VALUES[@]}"; do
    if [ "$v" = "$allowed" ]; then
      return 0
    fi
  done
  return 1
}

echo "--- fix-spec-frontmatter-shape sensor ---"

if [ ! -d "$FIXES_DIR" ]; then
  echo "PASS: ${FIXES_DIR}/ does not exist (no fix-specs to check)"
  echo "--- fix-spec-frontmatter-shape: ALL PASS (vacuous) ---"
  exit 0
fi

# Walk every <slug>.md under .yoke/fixes/. Use a glob so we don't trip
# on subdirectories (none expected; if any appear, the sensor's scope
# is still flat-file).
shopt -s nullglob
fixes=( "${FIXES_DIR}"/*.md )
shopt -u nullglob

if [ "${#fixes[@]}" -eq 0 ]; then
  echo "PASS: ${FIXES_DIR}/ is empty (no fix-specs to check)"
  echo "--- fix-spec-frontmatter-shape: ALL PASS (vacuous) ---"
  exit 0
fi

for fix in "${fixes[@]}"; do
  CHECKED=$((CHECKED + 1))

  if ! value="$(extract_field "$fix" "scope_caution")"; then
    fail "${fix}"
    echo "  violation: missing mandatory 'scope_caution:' frontmatter field" >&2
    echo "  fix: add a frontmatter line of the form '> scope_caution: <value>' where <value> is one of:" >&2
    echo "    <empty>            (4/4 narrowness proxies passed)" >&2
    echo "    component-breadth" >&2
    echo "    contract-shape" >&2
    echo "    trigger-specificity" >&2
    echo "    surface-containment" >&2
    continue
  fi

  if is_allowed_value "$value"; then
    if [ -z "$value" ]; then
      pass "${fix}: scope_caution is empty (4/4 narrowness proxies passed)"
    else
      pass "${fix}: scope_caution = '${value}'"
    fi
  else
    fail "${fix}"
    echo "  violation: 'scope_caution: ${value}' is not a documented value" >&2
    echo "  observed: '${value}'" >&2
    echo "  fix: replace the frontmatter value with one of:" >&2
    echo "    <empty>            (4/4 narrowness proxies passed)" >&2
    echo "    component-breadth" >&2
    echo "    contract-shape" >&2
    echo "    trigger-specificity" >&2
    echo "    surface-containment" >&2
  fi
done

echo "--- fix-spec-frontmatter-shape: ${CHECKED} fix-specs checked ---"

if [ "$FAIL" -eq 0 ]; then
  echo "--- fix-spec-frontmatter-shape: ALL PASS ---"
  exit 0
else
  echo "--- fix-spec-frontmatter-shape: FAILURES ABOVE ---" >&2
  exit 1
fi
