#!/bin/bash
# migration-audit.sh — pre-migration audit of `.yoke/sensors/` against
# the union of sensor ids referenced by every contract under
# `.yoke/acceptance-contracts/`. Produces a parseable, fixed-column
# tabular report on stdout listing each catalog id as either
# `still-referenced` or `orphan-candidate-for-delete`, plus any
# `dangling-reference` (referenced by a contract but absent from the
# catalog) on stderr.
#
# Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md.
#
# Reference patterns recognized in contracts:
#   - New shape (post-realignment): bullet under `### Validation`
#       `- **<sensor-id>** — ...`.
#   - Legacy shape: `- id: <sensor-id>` under `## Sensors registry`.
#   - Legacy shape: `Sensors: [id1, id2]` line in BDD scenarios.
#
# Usage:
#   bash lib/sensors/migration-audit.sh [--root <dir>]
#
# `--root <dir>` resolves contracts under `<dir>/contracts/` and
# the catalog under `<dir>/sensors/` (used by the test fixture). With
# no `--root`, contracts come from `.yoke/acceptance-contracts/` and
# the catalog from `.yoke/sensors/` under the current working directory.
#
# Output:
#   stdout — one line per catalog member:
#     <id>\t<status>
#   followed by a summary line:
#     # <total> total: <X> still-referenced, <Y> orphan-candidate, <Z> dangling
#
# Exit codes:
#   0 — audit completed; no dangling references.
#   2 — usage error (missing directory etc).
#   4 — at least one dangling reference detected.

set -euo pipefail

root_dir=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      if [ $# -lt 2 ]; then
        echo "Error: --root requires a value." >&2
        exit 2
      fi
      root_dir="$2"
      shift 2
      ;;
    --root=*)
      root_dir="${1#--root=}"
      shift
      ;;
    -h|--help)
      sed -n '2,/^# Exit codes/p' "$0" >&2 || true
      exit 0
      ;;
    *)
      echo "Error: unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -n "$root_dir" ]; then
  contracts_dir="${root_dir%/}/contracts"
  sensors_dir="${root_dir%/}/sensors"
else
  contracts_dir=".yoke/acceptance-contracts"
  sensors_dir=".yoke/sensors"
fi

if [ ! -d "$contracts_dir" ]; then
  echo "Error: contracts directory '${contracts_dir}' not found." >&2
  exit 2
fi
if [ ! -d "$sensors_dir" ]; then
  echo "Error: sensors directory '${sensors_dir}' not found." >&2
  exit 2
fi

# Collect referenced ids from every contract.
referenced_ids="$(
  shopt -s nullglob
  for cf in "$contracts_dir"/*.md; do
    awk '
      # New shape: bullets under `### Validation` like `- **id** —`.
      /^### Validation[[:space:]]*$/ { in_v = 1; next }
      in_v && /^### / && !/^### Validation/ { in_v = 0 }
      in_v && /^## / { in_v = 0 }
      in_v && /^[[:space:]]*-[[:space:]]+\*\*[a-z0-9-]+\*\*/ {
        match($0, /\*\*[a-z0-9-]+\*\*/)
        if (RSTART > 0) {
          print substr($0, RSTART + 2, RLENGTH - 4)
        }
      }
      # Legacy registry: `- id: <id>` under `## Sensors registry`.
      /^## Sensors registry/ { in_r = 1; next }
      in_r && /^## / && !/^## Sensors registry/ { in_r = 0 }
      in_r && /^[[:space:]]*-[[:space:]]+id:[[:space:]]*/ {
        v = $0
        sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", v)
        sub(/[[:space:]]+$/, "", v)
        if (v != "") print v
      }
      # Legacy scenario sensors line.
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
)"

# Collect catalog ids (filename stem under sensors_dir).
catalog_ids="$(
  find "$sensors_dir" -maxdepth 1 -type f -name '*.md' -print 2>/dev/null \
    | sed -e 's|^.*/||' -e 's|\.md$||' \
    | LC_ALL=C sort -u
)"

# Compute classifications.
# still-referenced  = catalog ∩ referenced
# orphan-candidate  = catalog \ referenced
# dangling          = referenced \ catalog
still_referenced="$(LC_ALL=C comm -12 \
  <(printf '%s\n' "$catalog_ids") \
  <(printf '%s\n' "$referenced_ids") \
  | grep -v '^$' || true)"

orphan_candidate="$(LC_ALL=C comm -23 \
  <(printf '%s\n' "$catalog_ids") \
  <(printf '%s\n' "$referenced_ids") \
  | grep -v '^$' || true)"

dangling="$(LC_ALL=C comm -13 \
  <(printf '%s\n' "$catalog_ids") \
  <(printf '%s\n' "$referenced_ids") \
  | grep -v '^$' || true)"

# Emit report. Catalog members first, in alphabetical order.
n_still=0
n_orphan=0
n_dangling=0

if [ -n "$still_referenced" ]; then
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    printf '%s\tstill-referenced\n' "$id"
    n_still=$((n_still + 1))
  done <<< "$still_referenced"
fi

if [ -n "$orphan_candidate" ]; then
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    printf '%s\torphan-candidate-for-delete\n' "$id"
    n_orphan=$((n_orphan + 1))
  done <<< "$orphan_candidate"
fi

if [ -n "$dangling" ]; then
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    printf '%s\tdangling-reference\n' "$id" >&2
    n_dangling=$((n_dangling + 1))
  done <<< "$dangling"
fi

total=$((n_still + n_orphan))
printf '# total=%d kept=%d orphan=%d dangling=%d\n' \
  "$total" "$n_still" "$n_orphan" "$n_dangling"

if [ "$n_dangling" -gt 0 ]; then
  exit 4
fi
exit 0
