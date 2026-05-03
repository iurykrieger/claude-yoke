#!/usr/bin/env bash
# shellcheck shell=bash
#
# spec-md-design-doc-shape.test.sh — Sprint 01 / Task t01 (happy-path
# unit tests for the rewritten `templates/spec.md`).
#
# Asserts the template carries the twelve canonical H2 sections in the
# documented order with the placeholder body shape that downstream
# self-checks rely on:
#
#   1. exactly twelve `## ` H2 sections present
#   2. headings appear in the documented order
#   3. `## Non-Functional Requirements` placeholder body contains at
#      least one numeric-unit pair (e.g. "200ms", "99.9%", "50 rps")
#   4. `## Alternatives Considered` placeholder body contains the three
#      required labels (`**Trade-off vs. chosen:**`,
#      `**Reason for rejection:**`, `**Source:**`)
#   5. `## Technical Use Cases` placeholder body contains the four
#      required labels (`**Components involved:**`,
#      `**Contracts used:**`, `**NFRs applied:**`, `**Edge cases:**`)
#
# These checks mirror the post-draft self-checks the rewritten
# `/yoke:tech-spec` runs against generated specs. Pinning them here at
# the template level guarantees the seed is well-shaped — when the
# template is broken, every generated spec will be broken, so the
# template-level test is the cheapest gate.
#
# Discovery: enumerated by Sprint 01 / Task t01's
# **Acceptance criterion** line and by Acceptance Contract Scenario 1.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"
cd "$PLUGIN_ROOT"

TEMPLATE="${PLUGIN_ROOT}/templates/spec.md"

if [ ! -f "$TEMPLATE" ]; then
    err "templates/spec.md missing at $TEMPLATE"
    harness::summary
fi

# --- 1. exactly twelve H2 sections of the documented kind -----------------

twelve_count="$(grep -cE '^## (Context and Scope|Goals and Non-Goals|System Context|Architecture|Stack and Dependencies|APIs and Data Model|Non-Functional Requirements|Alternatives Considered|Trade-offs|Cross-cutting Concerns|Technical Use Cases|Open Questions)$' "$TEMPLATE")"
if [ "$twelve_count" = "12" ]; then
    pass "templates/spec.md carries exactly 12 documented H2 sections"
else
    err "templates/spec.md H2 count mismatch (expected 12, got $twelve_count)"
fi

# --- 2. headings appear in the documented order ---------------------------

# The canonical order list — the post-draft self-check in
# `/yoke:tech-spec` enforces the same ordering against generated specs.
expected_order=(
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

mapfile -t actual_order < <(grep -E '^## ' "$TEMPLATE")

ordered=true
for i in "${!expected_order[@]}"; do
    expected="${expected_order[$i]}"
    actual="${actual_order[$i]:-<missing>}"
    if [ "$expected" != "$actual" ]; then
        ordered=false
        err "templates/spec.md H2 #$((i + 1)) order mismatch (expected '$expected', got '$actual')"
        break
    fi
done

if [ "$ordered" = "true" ]; then
    pass "templates/spec.md H2 sections appear in the documented order"
fi

# --- 3. NFR section carries at least one numeric-unit pair ----------------

# Extract the body between `## Non-Functional Requirements` and the
# next `## ` heading.
nfr_body="$(awk '/^## Non-Functional Requirements$/{flag=1; next} /^## /{flag=0} flag' "$TEMPLATE")"

if printf '%s' "$nfr_body" | grep -iqE '[0-9]+(\.[0-9]+)?\s*(ms|s|%|rps|qps|req/s|MB|GB|TB|users)'; then
    pass "## Non-Functional Requirements placeholder body contains ≥ 1 numeric-unit pair"
else
    err "## Non-Functional Requirements placeholder body has no numeric-unit pair (regex: \\d+(\\.\\d+)?\\s*(ms|s|%|rps|qps|req/s|MB|GB|TB|users) case-insensitive)"
fi

# --- 4. Alternatives section carries the three required labels -----------

alt_body="$(awk '/^## Alternatives Considered$/{flag=1; next} /^## /{flag=0} flag' "$TEMPLATE")"

for label in '**Trade-off vs. chosen:**' '**Reason for rejection:**' '**Source:**'; do
    if printf '%s' "$alt_body" | grep -qF "$label"; then
        pass "## Alternatives Considered carries label '$label'"
    else
        err "## Alternatives Considered missing label '$label'"
    fi
done

# --- 5. Technical Use Cases section carries the four required labels ------

uc_body="$(awk '/^## Technical Use Cases$/{flag=1; next} /^## /{flag=0} flag' "$TEMPLATE")"

for label in '**Components involved:**' '**Contracts used:**' '**NFRs applied:**' '**Edge cases:**'; do
    if printf '%s' "$uc_body" | grep -qF "$label"; then
        pass "## Technical Use Cases carries label '$label'"
    else
        err "## Technical Use Cases missing label '$label'"
    fi
done

harness::summary
