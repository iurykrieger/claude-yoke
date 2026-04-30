#!/usr/bin/env bash
# tests/sensors/migration.test.sh — one-shot post-migration health check
# for Sprint 3 t02 of the sensor-harness-realignment PRD.
#
# This test is deliberately scoped to the post-migration state of the
# host project's `.yoke/sensors/` catalog and `.yoke/acceptance-contracts/`
# tree. It is a one-shot — discardable after the realignment PRD merges
# — but kept until then to gate any silent regression that reintroduces
# legacy fields, breaks readiness, or leaves a dangling reference.
#
# Six assertions:
#   (a) zero sensor files carry any of `class:`, `tier:`, `applies_to:`,
#       `runs:`.
#   (b) every surviving file passes `ack-sensors.sh --mode readiness`
#       with exit 0.
#   (c) every `sensor: <id>` reference in any contract under
#       `.yoke/acceptance-contracts/` resolves to a file in
#       `.yoke/sensors/`.
#   (d) every surviving file has `type:`, `token_cost:`, `time_cost:`
#       populated in its frontmatter.
#   (e) every `type: computational` carries `command:`; every
#       `type: inferential` carries `agent:` (mutually exclusive).
#   (f) body shape preserved — every survivor contains `## How to run`,
#       `## Known issues`, `## Frequent errors`, plus `## Calibration`
#       for inferential.
#
# Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAIL=0
fail() { echo "FAIL: $*" >&2; FAIL=1; }
pass() { echo "PASS: $*"; }

echo "--- sensor-harness-realignment migration health checks ---"

# ---------------------------------------------------------------------------
# Assertion (a): zero legacy fields anywhere in .yoke/sensors/.
# ---------------------------------------------------------------------------
legacy_count=$({ find .yoke/sensors -name '*.md' -type f 2>/dev/null \
  | xargs grep -lE '^(class|tier|applies_to|runs):' 2>/dev/null \
  || true; } | wc -l | tr -d ' ')
if [ "$legacy_count" != "0" ]; then
  fail "legacy fields (class/tier/applies_to/runs) survived in $legacy_count file(s)"
else
  pass "zero legacy fields across .yoke/sensors/"
fi

# ---------------------------------------------------------------------------
# Assertion (b): every survivor passes readiness with exit 0.
# ---------------------------------------------------------------------------
readiness_failures=0
for f in .yoke/sensors/*.md; do
  [ -f "$f" ] || continue
  if ! bash lib/sensors/ack-sensors.sh --mode readiness "$f" >/dev/null 2>&1; then
    fail "readiness exits non-zero for $f"
    readiness_failures=$((readiness_failures + 1))
  fi
done
if [ "$readiness_failures" -eq 0 ]; then
  pass "every survivor passes ack-sensors.sh --mode readiness"
fi

# ---------------------------------------------------------------------------
# Assertion (c): every contract sensor reference resolves.
# Reads bullets `- **<id>** —` under `### Validation` and the legacy
# `- id: <id>` under `## Sensors registry` and the `Sensors: [a, b]`
# scenario lines. Sub-directories (`historical/`) are deliberately
# skipped — those are archived contracts kept for git audit only.
# ---------------------------------------------------------------------------
referenced_ids=$(
  shopt -s nullglob
  for cf in .yoke/acceptance-contracts/*.md; do
    [ -f "$cf" ] || continue
    awk '
      /^### Validation[[:space:]]*$/ { in_v = 1; next }
      in_v && /^### / && !/^### Validation/ { in_v = 0 }
      in_v && /^## / { in_v = 0 }
      in_v && /^[[:space:]]*-[[:space:]]+\*\*[a-z0-9-]+\*\*/ {
        match($0, /\*\*[a-z0-9-]+\*\*/)
        if (RSTART > 0) {
          print substr($0, RSTART + 2, RLENGTH - 4)
        }
      }
      /^## Sensors registry/ { in_r = 1; next }
      in_r && /^## / && !/^## Sensors registry/ { in_r = 0 }
      in_r && /^[[:space:]]*-[[:space:]]+id:[[:space:]]*/ {
        v = $0
        sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", v)
        sub(/[[:space:]]+$/, "", v)
        if (v != "") print v
      }
      /^Sensors:[[:space:]]*\[/ {
        line = $0
        sub(/^Sensors:[[:space:]]*\[/, "", line)
        sub(/\][[:space:]]*$/, "", line)
        n = split(line, arr, ",")
        for (i = 1; i <= n; i++) {
          v = arr[i]
          sub(/^[[:space:]]+/, "", v)
          sub(/[[:space:]]+$/, "", v)
          if (v != "") print v
        }
      }
    ' "$cf"
  done | LC_ALL=C sort -u
)

dangling=0
while IFS= read -r id; do
  [ -z "$id" ] && continue
  if [ ! -f ".yoke/sensors/${id}.md" ]; then
    fail "contract references missing sensor: ${id}"
    dangling=$((dangling + 1))
  fi
done <<< "$referenced_ids"
if [ "$dangling" -eq 0 ]; then
  pass "every contract sensor reference resolves to a .yoke/sensors/<id>.md file"
fi

# ---------------------------------------------------------------------------
# Assertion (d): every survivor has type / token_cost / time_cost.
# ---------------------------------------------------------------------------
missing_fields=0
for f in .yoke/sensors/*.md; do
  [ -f "$f" ] || continue
  fm=$(awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; if(c==2) exit; next} c==1{print}' "$f")
  for field in type token_cost time_cost; do
    if ! printf '%s\n' "$fm" | grep -qE "^${field}:"; then
      fail "missing required field '${field}:' in ${f}"
      missing_fields=$((missing_fields + 1))
    fi
  done
done
if [ "$missing_fields" -eq 0 ]; then
  pass "every survivor declares type / token_cost / time_cost"
fi

# ---------------------------------------------------------------------------
# Assertion (e): type/command-or-agent invariant.
# ---------------------------------------------------------------------------
invariant_violations=0
for f in .yoke/sensors/*.md; do
  [ -f "$f" ] || continue
  fm=$(awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; if(c==2) exit; next} c==1{print}' "$f")
  type_v=$(printf '%s\n' "$fm" | awk '/^type:/ { sub(/^type:[[:space:]]*/, ""); print; exit }')
  has_cmd=0; has_agent=0
  printf '%s\n' "$fm" | grep -q '^command:' && has_cmd=1
  printf '%s\n' "$fm" | grep -q '^agent:' && has_agent=1
  case "$type_v" in
    computational)
      if [ "$has_cmd" -ne 1 ]; then
        fail "computational sensor missing command: ${f}"
        invariant_violations=$((invariant_violations + 1))
      fi
      if [ "$has_agent" -eq 1 ]; then
        fail "computational sensor declares agent: (mutually exclusive): ${f}"
        invariant_violations=$((invariant_violations + 1))
      fi
      ;;
    inferential)
      if [ "$has_agent" -ne 1 ]; then
        fail "inferential sensor missing agent: ${f}"
        invariant_violations=$((invariant_violations + 1))
      fi
      if [ "$has_cmd" -eq 1 ]; then
        fail "inferential sensor declares command: (mutually exclusive): ${f}"
        invariant_violations=$((invariant_violations + 1))
      fi
      ;;
    *)
      fail "unknown type '${type_v}' in ${f}"
      invariant_violations=$((invariant_violations + 1))
      ;;
  esac
done
if [ "$invariant_violations" -eq 0 ]; then
  pass "type/command-or-agent invariant holds across the catalog"
fi

# ---------------------------------------------------------------------------
# Assertion (f): body shape preserved.
# ---------------------------------------------------------------------------
body_violations=0
for f in .yoke/sensors/*.md; do
  [ -f "$f" ] || continue
  body=$(awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; next} c>=2{print}' "$f")
  fm=$(awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; if(c==2) exit; next} c==1{print}' "$f")
  type_v=$(printf '%s\n' "$fm" | awk '/^type:/ { sub(/^type:[[:space:]]*/, ""); print; exit }')

  for header in "## How to run" "## Known issues" "## Frequent errors"; do
    if ! printf '%s\n' "$body" | grep -qE "^${header}\$"; then
      fail "missing '${header}' in ${f}"
      body_violations=$((body_violations + 1))
    fi
  done

  if [ "$type_v" = "inferential" ]; then
    if ! printf '%s\n' "$body" | grep -qE '^## Calibration$'; then
      fail "inferential sensor missing '## Calibration' in ${f}"
      body_violations=$((body_violations + 1))
    fi
  fi
done
if [ "$body_violations" -eq 0 ]; then
  pass "body shape (How to run / Known issues / Frequent errors / Calibration on inferential) preserved"
fi

if [ "$FAIL" -eq 0 ]; then
  echo "--- sensor-harness-realignment migration: ALL PASS ---"
  exit 0
else
  echo "--- sensor-harness-realignment migration: FAILURES ABOVE ---" >&2
  exit 1
fi
