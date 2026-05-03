#!/usr/bin/env bash
# criterion: tech-spec-design-doc-shape
# criterion: tech-spec-no-task-anchors
# criterion: tech-spec-no-sprint-files-from-phase-2
# criterion: tech-spec-quantitative-nfr-rejector
# criterion: tech-spec-alternatives-triple-rejector
# criterion: tech-spec-stack-auto-detect
# criterion: tech-spec-canonical-memory-query
# criterion: tech-spec-web-search-threshold-fallback
# criterion: tech-spec-us-id-lifted-into-technical-use-cases
#
# Scenario 2 — `/yoke:tech-spec` produces design doc with no sprint side-effects.
# Binding contract: .yoke/acceptance-contracts/2026-05-03-tech-spec-as-design-doc.md
#   Scenario 2 (Task ...-s01-t02) + FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7, FR-8, FR-14.
#
# Driving `/yoke:tech-spec` end-to-end requires an interactive LLM
# dialogue, which is out of scope for a bash acceptance test. Instead
# this test pins the **deterministic** invariants the rewritten skill
# must encode:
#
#   (a) static contract of `skills/tech-spec/SKILL.md`:
#       - drops the legacy `lib/working-memory/scaffold-sprints.sh`
#         invocation (FR-11; per s01-t02 Validation)
#       - declares the twelve-section design-doc shape and the four
#         stack-detection manifests by name in the skill body
#       - declares a `/yoke:search-canonical-memory` invocation
#         (FR-3 / `tech-spec-canonical-memory-query`)
#       - declares a `WebSearch` fallback gated by
#         `overrides.tech_spec.canonical_pattern_threshold`
#         (FR-3 / `tech-spec-web-search-threshold-fallback`)
#       - declares the four post-draft self-checks by their
#         observable signature (`### Task ` zero-count;
#         `.yoke/sprints/` zero-count; quantitative-NFR regex;
#         Alternatives triple labels)
#
#   (b) behavioral self-check assertions against synthetic spec
#       bodies (the skill's deterministic post-draft greps):
#       - a well-formed twelve-section spec with US-### lifts and
#         quantitative NFRs PASSES every documented grep.
#       - a spec missing one H2 FAILS the shape grep.
#       - a spec containing `### Task` anchors FAILS the no-task-
#         anchors grep.
#       - an adjective-only NFR bullet FAILS the quantitative-NFR
#         regex.
#       - an `### Alt: ...` subsection missing `**Source:**` FAILS
#         the triple-shape grep.
#       - dropping a PRD US-### silently FAILS the lift grep.
#
# Negative regression check: against the pre-cutover skill (the
# legacy `skills/tech-spec/SKILL.md` still references
# `scaffold-sprints` and ships the 3-stage blueprint), assertion (a)
# fails — this test pins the new behavior and rejects the legacy.

set -euo pipefail

( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

SKILL="skills/tech-spec/SKILL.md"

# --- (a) static contract of the rewritten /yoke:tech-spec skill -------------

if [[ ! -f "$SKILL" ]]; then
    echo "FAIL: $SKILL missing on disk" >&2
    exit 1
fi

# (a.1) FR-11 / s01-t02 Validation: scaffold-sprints invocation removed
#       from Phase 2.
n_scaffold="$(grep -c 'scaffold-sprints' "$SKILL" || true)"
if [[ "$n_scaffold" != "0" ]]; then
    echo "FAIL: $SKILL still references 'scaffold-sprints' ($n_scaffold occurrences); FR-11 requires Phase 2 not invoke scaffold-sprints.sh" >&2
    exit 1
fi

# (a.2) twelve-section design-doc shape declared in the skill body.
required_section_strings=(
    "Context and Scope"
    "Goals and Non-Goals"
    "System Context"
    "Architecture"
    "Stack and Dependencies"
    "APIs and Data Model"
    "Non-Functional Requirements"
    "Alternatives Considered"
    "Trade-offs"
    "Cross-cutting Concerns"
    "Technical Use Cases"
    "Open Questions"
)
for s in "${required_section_strings[@]}"; do
    if ! grep -qF "$s" "$SKILL"; then
        echo "FAIL: $SKILL does not declare H2 section '$s' in its body (FR-4 design-doc shape)" >&2
        exit 1
    fi
done

# (a.3) four stack-detection manifests named (FR-1).
for manifest in "package.json" "go.mod" "Cargo.toml" "pyproject.toml"; do
    if ! grep -qF "$manifest" "$SKILL"; then
        echo "FAIL: $SKILL does not name manifest file '$manifest' (FR-1 stack auto-detection)" >&2
        exit 1
    fi
done

# (a.4) canonical-memory query call declared (FR-3 / first half).
if ! grep -qF '/yoke:search-canonical-memory' "$SKILL"; then
    echo "FAIL: $SKILL does not invoke /yoke:search-canonical-memory (FR-3 canonical-memory query)" >&2
    exit 1
fi

# (a.5) WebSearch fallback gated by the threshold (FR-3 / second half).
if ! grep -qF 'WebSearch' "$SKILL"; then
    echo "FAIL: $SKILL does not reference 'WebSearch' (FR-3 threshold-gated fallback)" >&2
    exit 1
fi
if ! grep -qF 'overrides.tech_spec.canonical_pattern_threshold' "$SKILL"; then
    echo "FAIL: $SKILL does not name override key 'overrides.tech_spec.canonical_pattern_threshold' (FR-3 threshold)" >&2
    exit 1
fi

# (a.6) post-draft self-checks declared by their observable signature.
#       The four greps the skill body must encode (FR-5/FR-7/FR-8 + FR-4).
if ! grep -qE '### Task' "$SKILL"; then
    echo "FAIL: $SKILL does not declare the no-task-anchors self-check signature ('### Task ' grep) (FR-5)" >&2
    exit 1
fi
if ! grep -qE '\.yoke/sprints' "$SKILL"; then
    echo "FAIL: $SKILL does not declare the no-sprint-files self-check signature ('.yoke/sprints' grep) (FR-5)" >&2
    exit 1
fi
if ! grep -qE 'ms\|s\|%\|rps\|qps' "$SKILL"; then
    echo "FAIL: $SKILL does not declare the quantitative-NFR regex (units list including ms|s|%|rps|qps) (FR-7)" >&2
    exit 1
fi
if ! grep -qF '**Trade-off vs. chosen:**' "$SKILL"; then
    echo "FAIL: $SKILL does not declare the Alternatives '**Trade-off vs. chosen:**' label self-check (FR-8)" >&2
    exit 1
fi

# --- (b) deterministic self-check behavior on synthetic spec bodies ----------

TMPDIR_ABS="$(mktemp -d -t yoke-s2-XXXXXX)"
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true; rm -rf "$TMPDIR_ABS"' EXIT

# Helper: assert grep -cE returns the expected count for a given pattern.
assert_grep_count() {
    local pattern="$1"; local file="$2"; local expected="$3"; local label="$4"
    local got
    got="$(grep -cE "$pattern" "$file" || true)"
    if [[ "$got" != "$expected" ]]; then
        echo "FAIL: $label — grep -cE '$pattern' '$file' returned '$got'; expected '$expected'" >&2
        exit 1
    fi
}

# (b.1) well-formed twelve-section spec with US-### lifts + numeric NFRs.
#       Pinned by hand; mirrors the shape `/yoke:tech-spec` must
#       produce post-cutover.
GOOD_SPEC="$TMPDIR_ABS/good.md"
cat >"$GOOD_SPEC" <<'EOF'
# Spec: Sample design doc

> Generated by `/yoke:tech-spec` from PRD on 2026-05-03.
> Status: draft

## Context and Scope
Body for context.

## Goals and Non-Goals
Body for goals.

## System Context
Body for system context.

## Architecture
Body for architecture.

## Stack and Dependencies
Body for stack.

## APIs and Data Model
Body for APIs.

## Non-Functional Requirements

- **Latency:** p95 < 200ms
- **Availability:** 99.9%

## Alternatives Considered

### Alt: GraphQL gateway

**Trade-off vs. chosen:** higher schema upkeep cost.
**Reason for rejection:** team unfamiliarity with N+1 caching.
**Source:** [[concepts/example-pattern-rest-vs-graphql]]

## Trade-offs
Body for trade-offs.

## Cross-cutting Concerns
Body for cross-cutting.

## Technical Use Cases

### US-001 — Submit form

**Components involved:** form, api
**Contracts used:** POST /submit
**NFRs applied:** Latency
**Edge cases:** validation errors

### US-002 — Read result

**Components involved:** ui
**Contracts used:** GET /result
**NFRs applied:** Latency
**Edge cases:** empty state

## Open Questions
None.
EOF

# Twelve-section grep — must return 12 in order.
assert_grep_count '^## (Context and Scope|Goals and Non-Goals|System Context|Architecture|Stack and Dependencies|APIs and Data Model|Non-Functional Requirements|Alternatives Considered|Trade-offs|Cross-cutting Concerns|Technical Use Cases|Open Questions)$' \
    "$GOOD_SPEC" "12" "good spec twelve-section grep"

# No task anchors.
assert_grep_count '^### Task ' "$GOOD_SPEC" "0" "good spec no-task-anchors grep"

# Every PRD US-### appears as `### US-### —`.
for us in "US-001" "US-002"; do
    if ! grep -qE "^### $us " "$GOOD_SPEC"; then
        echo "FAIL: good spec missing '### $us — ...' subsection (FR-6 US-### lift)" >&2
        exit 1
    fi
done

# NFR bullets all carry quantitative units.
nfr_block="$(awk '/^## Non-Functional Requirements/{flag=1; next} flag && /^## /{flag=0} flag' "$GOOD_SPEC")"
nfr_bullets="$(grep -E '^- ' <<<"$nfr_block" || true)"
if [[ -z "$nfr_bullets" ]]; then
    echo "FAIL: good spec NFR section has no bullets" >&2
    exit 1
fi
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! grep -qiE '\b[0-9]+(\.[0-9]+)?[[:space:]]*(ms|s|%|rps|qps|req/s|MB|GB|TB|users)\b' <<<"$line"; then
        echo "FAIL: good spec NFR bullet missing quantitative target: '$line'" >&2
        exit 1
    fi
done <<<"$nfr_bullets"

# Every Alternatives subsection carries the three labels.
alt_block="$(awk '/^## Alternatives Considered/{flag=1; next} flag && /^## /{flag=0} flag' "$GOOD_SPEC")"
for label in '**Trade-off vs. chosen:**' '**Reason for rejection:**' '**Source:**'; do
    if ! grep -qF "$label" <<<"$alt_block"; then
        echo "FAIL: good spec Alternatives section missing label '$label'" >&2
        exit 1
    fi
done

# (b.2) negative — twelve-section grep on a spec missing a section MUST fail.
BAD_SHAPE="$TMPDIR_ABS/bad-shape.md"
cat >"$BAD_SHAPE" <<'EOF'
## Context and Scope
## Goals and Non-Goals
## System Context
## Architecture
## Stack and Dependencies
## APIs and Data Model
## Non-Functional Requirements
## Alternatives Considered
## Trade-offs
## Cross-cutting Concerns
## Open Questions
EOF
shape_count="$(grep -cE '^## (Context and Scope|Goals and Non-Goals|System Context|Architecture|Stack and Dependencies|APIs and Data Model|Non-Functional Requirements|Alternatives Considered|Trade-offs|Cross-cutting Concerns|Technical Use Cases|Open Questions)$' "$BAD_SHAPE" || true)"
if [[ "$shape_count" == "12" ]]; then
    echo "FAIL: bad-shape spec (missing '## Technical Use Cases') unexpectedly returned 12 from the FR-4 grep — self-check is broken" >&2
    exit 1
fi

# (b.3) negative — task-anchor grep MUST fire on a spec containing `### Task`.
BAD_TASKS="$TMPDIR_ABS/bad-tasks.md"
cat >"$BAD_TASKS" <<'EOF'
## Architecture
### Task 2026-05-03-foo-s01-t01
**Story:** illegal task anchor in Phase 2 spec body.
EOF
task_count="$(grep -cE '^### Task ' "$BAD_TASKS" || true)"
if [[ "$task_count" == "0" ]]; then
    echo "FAIL: bad-tasks spec contains '### Task' but the no-task-anchors grep returned 0 — self-check is broken" >&2
    exit 1
fi

# (b.4) negative — adjective-only NFR fails the quantitative regex.
BAD_NFR="- **Performance:** fast"
if grep -qiE '\b[0-9]+(\.[0-9]+)?[[:space:]]*(ms|s|%|rps|qps|req/s|MB|GB|TB|users)\b' <<<"$BAD_NFR"; then
    echo "FAIL: adjective-only NFR ('$BAD_NFR') unexpectedly matched the quantitative-target regex" >&2
    exit 1
fi

# (b.5) negative — Alternatives entry missing `**Source:**` fails the triple grep.
BAD_ALT="$TMPDIR_ABS/bad-alt.md"
cat >"$BAD_ALT" <<'EOF'
## Alternatives Considered

### Alt: Some option

**Trade-off vs. chosen:** something.
**Reason for rejection:** something else.
EOF
alt_block_bad="$(awk '/^## Alternatives Considered/{flag=1; next} flag && /^## /{flag=0} flag' "$BAD_ALT")"
if grep -qF '**Source:**' <<<"$alt_block_bad"; then
    echo "FAIL: bad-alt fixture unexpectedly contains '**Source:**' — fixture is wrong" >&2
    exit 1
fi
# The assertion the skill encodes: missing label triggers an abort.
# Here we just confirm the grep correctly identifies the gap.

# (b.6) negative — silently dropping a PRD US-### must be detectable.
DROPPED="$TMPDIR_ABS/dropped.md"
cat >"$DROPPED" <<'EOF'
## Technical Use Cases

### US-001 — Submit form
**Components involved:** form
EOF
# US-002 was in the PRD but is missing from the spec.
if grep -qE '^### US-002 ' "$DROPPED"; then
    echo "FAIL: dropped fixture unexpectedly contains '### US-002' — fixture is wrong" >&2
    exit 1
fi
# The assertion the skill encodes: the silent drop is detected.
# Here we just confirm the grep correctly identifies the gap.

echo "OK: tests/acceptance/2026-05-03-tech-spec-as-design-doc/scenario-2-tech-spec-no-sprint-side-effects.test.sh"
exit 0
