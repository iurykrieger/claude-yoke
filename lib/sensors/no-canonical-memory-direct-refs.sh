#!/usr/bin/env bash
# Sensor: zero direct references to v2.0.0-extracted canonical-memory
# helpers from any script under lib/sensors/.
#
# v2.0.0 facade rule: lib/canonical-""memory/ retains only
# resolve-provider.sh; every other helper that used to live there was
# extracted to the claude-bedrock peer plugin per the canonized
# decision yoke-decision-2026-04-30-namespace-separation-yoke-vs-provider.
# Sensors are downstream of the facade boundary
# (yoke-pattern-facade-vs-provider-verbs) and MUST NOT source those
# helpers directly. Forbidden references previously caused silent
# exit-2 failures that the harness treated as "environmental skip",
# masking drift.
#
# Self-reference paradox: the sensor's body must name the forbidden
# basenames to detect them. Two mitigations:
#   1. The canonical-memory directory prefix and the forbidden basename
#      list are constructed at runtime from string parts so the
#      sensor's own source carries no literal forbidden full-path
#      string. Mirrors the no-vibeflow-refs.sh paradox break.
#   2. The scan explicitly excludes the sensor's own file via
#      `grep -vF "$(basename "$0")"` as a belt-and-braces backup.
#
# Output convention (per concepts/yoke-pattern-sensors):
#   - Silent success (exit 0): no violations on stdout; no diagnostics on stderr.
#   - Violation (exit 1): one structured-YAML block per match on stdout
#     carrying id / location / correction_instruction / reference;
#     diagnostic summary line on stderr.
#   - Environmental (exit 2): --scan-dir missing or unknown flag.
#
# Source: .yoke/acceptance-criteria/2026-05-05-stale-sensor-canonical-memory-refs.md
# US-001 / US-002 / US-005; FR-3.

set -euo pipefail

scan_dir="lib/sensors"
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --scan-dir) scan_dir="${2:-}"; shift 2 ;;
    --scan-dir=*) scan_dir="${1#--scan-dir=}"; shift ;;
    -h|--help)
      sed -n '2,/^# Source/p' "$0" >&2
      exit 0
      ;;
    *)
      echo "no-canonical-memory-direct-refs: unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if [ ! -d "$scan_dir" ]; then
  echo "no-canonical-memory-direct-refs: scan-dir not found: $scan_dir" >&2
  exit 2
fi

# Construct the canonical-memory directory prefix from parts so this
# script's own source contains no literal `lib/canonical-memory/<X>`
# full-path token. The forbidden basename list enumerates exactly the
# helpers extracted to claude-bedrock at v2.0.0 (see commit 643500d
# diff over lib/canonical-memory/*.sh).
cm_prefix_a="lib/canonical-"
cm_prefix_b="memory"
cm_prefix="${cm_prefix_a}${cm_prefix_b}"

forbidden_basenames=(
  "canonization-criteria"
  "graph"
  "registry"
  "resolve-memory"
  "scaffold-memory"
  "semantic-overlap-rewrite"
  "trace-analyzer"
  "write-promoted-concept"
)

# Build the alternation pattern at runtime: lib/canonical-memory/(b1|b2|...)\.sh
pattern="${cm_prefix}/("
for i in "${!forbidden_basenames[@]}"; do
  if [ "$i" -gt 0 ]; then pattern="${pattern}|"; fi
  pattern="${pattern}${forbidden_basenames[$i]}"
done
pattern="${pattern})\\.sh"

self_file="$(basename "$0")"

# Recursive grep over *.sh files under $scan_dir; emit file:line:text.
matches="$(grep -rnE --include='*.sh' "$pattern" "$scan_dir" 2>/dev/null \
  | grep -vF "$self_file" \
  || true)"

if [ -z "$matches" ]; then
  exit 0
fi

violations=0
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  # entry shape: <file>:<line>:<text>
  file="${entry%%:*}"
  rest="${entry#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  # Extract every forbidden token on the line (multi-match per line).
  while IFS= read -r offending; do
    [ -n "$offending" ] || continue
    violations=$((violations + 1))
    printf -- '- id: "no-canonical-memory-direct-refs"\n'
    printf -- '  location: "%s:%s"\n' "$file" "$line"
    printf -- '  correction_instruction: "remove or replace the reference to %s in %s; v2.0.0 facade rule allows only %s/resolve-provider.sh under %s/. Sensors are downstream of the facade — read canonical memory via /yoke:search-canonical-memory."\n' \
      "$offending" "$file" "$cm_prefix" "$cm_prefix"
    printf -- '  reference: "[[yoke-pattern-facade-vs-provider-verbs]]"\n'
  done < <(printf '%s\n' "$text" | grep -oE "$pattern" || true)
done <<<"$matches"

echo "sensor: no-canonical-memory-direct-refs found ${violations} violation(s)" >&2
exit 1
