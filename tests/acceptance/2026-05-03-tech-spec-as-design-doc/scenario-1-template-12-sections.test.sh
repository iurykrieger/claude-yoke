#!/usr/bin/env bash
# criterion: tech-spec-template-12-section-shape
# criterion: config-override-reader-callable
# criterion: config-override-canonical-pattern-threshold
#
# Scenario 1 — New design-doc template + config-overrides reader.
# Binding contract: .yoke/acceptance-contracts/2026-05-03-tech-spec-as-design-doc.md
#   Scenario 1 (Task ...-s01-t01) + FR-4 (`tech-spec-design-doc-shape`).
#
# Pins three independent post-cutover invariants in one file:
#   (a) `templates/spec.md` carries exactly the twelve documented H2
#       sections in the documented order with no extra H2s in between.
#   (b) The placeholder bodies for `## Non-Functional Requirements`,
#       `## Alternatives Considered`, and `## Technical Use Cases`
#       demonstrate the expected shape (numeric-unit pair; three Alt
#       labels; four US-### labels).
#   (c) `lib/config-overrides.sh` exists, exposes `yoke_get_override`,
#       returns the supplied default when the key is absent, and
#       returns the configured value when the override is set.
#
# Negative regression check: against the pre-cutover code path
# (legacy `templates/spec.md` carrying the sprint-pointer shape and no
# `lib/config-overrides.sh` on disk), every assertion below fails —
# the test pins the new behavior, not a generic happy path.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Locate the repo root by walking up from this test file.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

TEMPLATE="templates/spec.md"
HELPER="lib/config-overrides.sh"

# --- (a) twelve H2 sections ------------------------------------------------

if [[ ! -f "$TEMPLATE" ]]; then
    echo "FAIL: $TEMPLATE missing on disk" >&2
    exit 1
fi

EXPECTED_H2=(
    "## Context and Scope"
    "## Goals and Non-Goals"
    "## System Context"
    "## Architecture"
    "## Stack and Dependencies"
    "## APIs and Data Model"
    "## Non-Functional Requirements"
    "## Alternatives Considered"
    "## Trade-offs"
    "## Cross-cutting Concerns"
    "## Technical Use Cases"
    "## Open Questions"
)

# Count via the contract's own regex.
count="$(grep -cE '^## (Context and Scope|Goals and Non-Goals|System Context|Architecture|Stack and Dependencies|APIs and Data Model|Non-Functional Requirements|Alternatives Considered|Trade-offs|Cross-cutting Concerns|Technical Use Cases|Open Questions)$' "$TEMPLATE" || true)"
if [[ "$count" != "12" ]]; then
    echo "FAIL: $TEMPLATE has $count of the 12 required H2 headings (expected 12 — see acceptance-contracts/2026-05-03-tech-spec-as-design-doc.md FR-4)" >&2
    exit 1
fi

# Order check: extract the H2 lines and diff against the expected sequence.
mapfile -t actual_h2 < <(grep -nE '^## ' "$TEMPLATE" | cut -d: -f2-)
i=0
for expected in "${EXPECTED_H2[@]}"; do
    if (( i >= ${#actual_h2[@]} )); then
        echo "FAIL: $TEMPLATE missing required heading '$expected' (ran out of H2s at position $i)" >&2
        exit 1
    fi
    if [[ "${actual_h2[$i]}" != "$expected" ]]; then
        echo "FAIL: $TEMPLATE H2 at position $i is '${actual_h2[$i]}', expected '$expected' (out-of-order or extra heading)" >&2
        exit 1
    fi
    i=$((i+1))
done
# Reject extra H2 headings beyond the twelve.
if (( ${#actual_h2[@]} != 12 )); then
    echo "FAIL: $TEMPLATE has ${#actual_h2[@]} H2 headings; expected exactly 12 (no extras allowed between or after the documented twelve)" >&2
    exit 1
fi

# --- (b) placeholder body shape compliance --------------------------------

# Extract the body of a given H2 section (text from after the heading line
# up to but not including the next H2 line). Single-section dispatcher.
section_body() {
    local section="$1"
    awk -v sec="$section" '
        $0 == sec { capture = 1; next }
        capture && /^## / { capture = 0 }
        capture { print }
    ' "$TEMPLATE"
}

NFR_BODY="$(section_body "## Non-Functional Requirements")"
# Numeric-unit pair per FR-7's regex.
if ! grep -qiE '\b[0-9]+(\.[0-9]+)?[[:space:]]*(ms|s|%|rps|qps|req/s|MB|GB|TB|users)\b' <<<"$NFR_BODY"; then
    echo "FAIL: $TEMPLATE :: ## Non-Functional Requirements placeholder body does not contain a numeric-unit pair (e.g., '200ms', '99.9%') — FR-7 quantitative-target rule" >&2
    exit 1
fi

ALT_BODY="$(section_body "## Alternatives Considered")"
for label in '**Trade-off vs. chosen:**' '**Reason for rejection:**' '**Source:**'; do
    if ! grep -qF "$label" <<<"$ALT_BODY"; then
        echo "FAIL: $TEMPLATE :: ## Alternatives Considered placeholder body missing required label '$label' (FR-8 triple-shape rule)" >&2
        exit 1
    fi
done

UC_BODY="$(section_body "## Technical Use Cases")"
for label in '**Components involved:**' '**Contracts used:**' '**NFRs applied:**' '**Edge cases:**'; do
    if ! grep -qF "$label" <<<"$UC_BODY"; then
        echo "FAIL: $TEMPLATE :: ## Technical Use Cases placeholder body missing required label '$label' (FR-6 US-### lift labels)" >&2
        exit 1
    fi
done

# --- (c) lib/config-overrides.sh contract ---------------------------------

if [[ ! -f "$HELPER" ]]; then
    echo "FAIL: $HELPER missing on disk (required by Scenario 1 / s01-t01 / FR-3)" >&2
    exit 1
fi

# (c.1) sources cleanly under bash -u and exposes yoke_get_override.
if ! bash -u -c "set -u; source '$HELPER' && type yoke_get_override >/dev/null 2>&1"; then
    echo "FAIL: $HELPER does not source cleanly under 'bash -u' or does not expose yoke_get_override" >&2
    exit 1
fi

# (c.2) returns the supplied default when the key is absent.
TMPDIR_ABS="$(mktemp -d -t yoke-co-XXXXXX)"
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true; rm -rf "$TMPDIR_ABS"' EXIT
mkdir -p "$TMPDIR_ABS/.yoke"
# Empty config — no overrides at all.
: >"$TMPDIR_ABS/.yoke/config.yaml"

result_default="$(
    cd "$TMPDIR_ABS"
    bash -c "source '$REPO_ROOT/$HELPER' && yoke_get_override overrides.tech_spec.canonical_pattern_threshold 3"
)"
if [[ "$result_default" != "3" ]]; then
    echo "FAIL: yoke_get_override default fallback returned '$result_default'; expected '3' (default supplied when key absent)" >&2
    exit 1
fi

# (c.3) returns the configured value when the override is set.
cat >"$TMPDIR_ABS/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0"
overrides:
  tech_spec:
    canonical_pattern_threshold: 5
YAML

result_override="$(
    cd "$TMPDIR_ABS"
    bash -c "source '$REPO_ROOT/$HELPER' && yoke_get_override overrides.tech_spec.canonical_pattern_threshold 3"
)"
if [[ "$result_override" != "5" ]]; then
    echo "FAIL: yoke_get_override override-set returned '$result_override'; expected '5' (value from .yoke/config.yaml :: overrides.tech_spec.canonical_pattern_threshold)" >&2
    exit 1
fi

echo "OK: tests/acceptance/2026-05-03-tech-spec-as-design-doc/scenario-1-template-12-sections.test.sh"
exit 0
