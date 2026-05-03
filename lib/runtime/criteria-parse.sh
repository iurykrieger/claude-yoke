#!/usr/bin/env bash
# criteria-parse.sh
#
# Parse the User Stories → Acceptance Criteria hierarchy of an
# Acceptance Criteria document and emit one `<US-ID>|<AC-ID>` tuple per
# line. The helper is the runtime building block that lets sensors,
# fixtures, or downstream tooling iterate the binding artifact's
# criteria deterministically without re-implementing the parser.
#
# Cites concepts/yoke-pattern-acceptance-contract for the artifact's
# binding-shape contract (superseded by the v4.0.0 acceptance-criteria
# pattern at canonization time) and concepts/yoke-pattern-plugin-structure
# for the lib/runtime/ layout convention.
#
# Usage:
#   source lib/runtime/criteria-parse.sh
#   criteria_parse <artifact-path>
#
# Output (stdout, one tuple per line):
#   US-001|AC-001-1
#   US-001|AC-001-2
#   US-002|AC-002-1
#   ...
#
# Exit codes:
#   0  Parse succeeded; tuples written to stdout (may be empty if the
#      artifact carries no AC entries).
#   2  Invalid arguments / artifact missing / unreadable.
#   3  Parse failure (malformed `### US-` / `#### Acceptance Criteria`
#      structure, e.g. AC entry outside any US block).

set -u

criteria_parse() {
  local artifact="${1:-}"
  if [ -z "$artifact" ]; then
    echo "wm: criteria_parse: artifact path required" >&2
    return 2
  fi
  if [ ! -f "$artifact" ]; then
    echo "wm: criteria_parse: artifact not found: $artifact" >&2
    return 2
  fi

  awk -v artifact="$artifact" '
    BEGIN {
      current_us = ""
      in_ac = 0
      saw_any = 0
      malformed = 0
    }

    # Match `### US-<digits> — <title>` (em-dash or hyphen).
    /^### US-[0-9]+/ {
      # Extract the US-### token.
      match($0, /US-[0-9]+/)
      if (RSTART > 0) {
        current_us = substr($0, RSTART, RLENGTH)
      }
      in_ac = 0
      next
    }

    # Match `#### Acceptance Criteria` heading inside a US block.
    /^#### Acceptance Criteria[[:space:]]*$/ {
      if (current_us == "") {
        printf "wm: criteria_parse: AC heading outside any US block in %s\n", artifact > "/dev/stderr"
        malformed = 1
      }
      in_ac = 1
      next
    }

    # Any new H2/H3/H4 closes the current AC list.
    /^#### Definition of Done/ { in_ac = 0; next }
    /^##/                      { in_ac = 0 }
    /^### / && !/^### US-/     { in_ac = 0 }

    # Bullet form `- **AC-<US>-<n>:** <text>` or `- AC-<US>-<n>: <text>`.
    in_ac && /^- [*]*AC-[0-9]+-[0-9]+/ {
      match($0, /AC-[0-9]+-[0-9]+/)
      if (RSTART > 0) {
        ac_id = substr($0, RSTART, RLENGTH)
        printf "%s|%s\n", current_us, ac_id
        saw_any = 1
      }
      next
    }

    END {
      if (malformed == 1) exit 3
      # Empty AC set is not a parse failure — the artifact may legitimately
      # carry only DoD checks while AC is still being authored, or be
      # intentionally cross-cutting via FRs.
      exit 0
    }
  ' "$artifact"
}

# Allow direct invocation: `bash lib/runtime/criteria-parse.sh <artifact>`
if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then
  criteria_parse "$@"
fi
