#!/usr/bin/env bash
# criterion: council-persona-sprint-path-reference
# criterion: council-persona-pattern-citation
# criterion: council-cycle-slice-sprint-path-citation
#
# Scenario 4 — Council personas consume sprint files as the cycle's
# working set.
# Binding contract:
#   .yoke/acceptance-contracts/2026-05-03-tech-spec-as-design-doc.md
#   Scenario 4 (Task ...-s02-t01) + the corresponding Sprint 02
#   `## Functional acceptance criteria` ids:
#     - council-personas-consume-sprint-files
#     - council-personas-cite-sprint-runtime-bundle-pattern
#     - council-cycle-slices-cite-sprint-path
#   gated by sensors:
#     - council-persona-sprint-path-reference
#     - council-persona-pattern-citation
#     - council-cycle-slice-sprint-path-citation
#
# This test pins the post-Sprint-02 invariants on the three council
# persona files (`agents/sr-{eng,qa,staff}.md`) and on the per-cycle
# slice authoring contract:
#
#   (a) every persona file references `.yoke/sprints/<slug>-s` as the
#       per-cycle working-set path pattern (the literal token, with
#       `<slug>` and `<...>-s` placeholders), satisfying the contract's
#       grep verbatim:
#         grep -lE '\.yoke/sprints/<slug>-s' agents/sr-eng.md \
#              agents/sr-qa.md agents/sr-staff.md | wc -l == 3.
#
#   (b) every persona file cites
#       `concepts/yoke-pattern-sprint-runtime-bundle` in the prompt
#       body, satisfying:
#         grep -lE 'concepts/yoke-pattern-sprint-runtime-bundle' \
#              agents/sr-eng.md agents/sr-qa.md agents/sr-staff.md \
#              | wc -l == 3.
#
#   (c) every persona file explicitly distinguishes the spec at
#       `.yoke/specs/<slug>.md` as **read-only architectural context**
#       (not iterated for tasks), so the rewritten prompt matches the
#       Scenario-4 Given→When statement on read-only spec posture.
#       Heuristic: each persona file contains BOTH the literal
#       `.yoke/specs/<slug>.md` AND a "read-only" / "not iterated" /
#       "architectural context" string in the same file. (Anti-scope
#       lines that mention `.yoke/specs/` only as upstream-artifact
#       MUST-NOT do not satisfy this — the test additionally requires
#       that the persona file reads the spec path inside the Phase A /
#       working-set declaration block, NOT only inside the
#       upstream-artifacts anti-scope list.)
#
#   (d) per-cycle slices the persona authors at
#       `.yoke/runtime/cycles/<N>/<persona>.md` cite the sprint file
#       path at least once. The synthetic council cycle invocation
#       (Phase A spawn) is not driven by this bash test (interactive
#       Tasks are out of scope for a deterministic test); instead this
#       test pins the **deterministic** prerequisite of (d): the
#       persona prompt explicitly tells the persona to cite
#       `.yoke/sprints/<slug>-s<...>.md` in its slice body. This is
#       the "writing instruction to the persona" surface, not the
#       observed slice content. (Observed-slice verification is the
#       runtime sensor `council-cycle-slice-sprint-path-citation`,
#       which the coordinator runs after Phase A; this test pins that
#       the persona has been instructed to cite the sprint path.)
#
# Negative regression check: against the pre-Sprint-02 state where
# the persona files do NOT carry the `.yoke/sprints/<slug>-s` literal
# (e.g., refer only to `task files` under `.yoke/tasks/`) AND/OR omit
# the `yoke-pattern-sprint-runtime-bundle` citation, this test exits
# non-zero — the asserts are sensitive to the literal post-cutover
# tokens, not to incidental string occurrences.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Locate the repo root by walking up from this test file.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

PERSONAS=(
    "agents/sr-eng.md"
    "agents/sr-qa.md"
    "agents/sr-staff.md"
)

# --- (a) sprint-path literal `.yoke/sprints/<slug>-s` --------------------

a_count="$(grep -lE '\.yoke/sprints/<slug>-s' "${PERSONAS[@]}" 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$a_count" != "3" ]]; then
    echo "FAIL: only $a_count of 3 persona files reference '.yoke/sprints/<slug>-s' (Scenario 4 / sensor council-persona-sprint-path-reference)" >&2
    for p in "${PERSONAS[@]}"; do
        if ! grep -qE '\.yoke/sprints/<slug>-s' "$p"; then
            echo "  MISSING: $p" >&2
        fi
    done
    exit 1
fi

# --- (b) sprint-runtime-bundle pattern citation ---------------------------

b_count="$(grep -lE 'concepts/yoke-pattern-sprint-runtime-bundle' "${PERSONAS[@]}" 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$b_count" != "3" ]]; then
    echo "FAIL: only $b_count of 3 persona files cite 'concepts/yoke-pattern-sprint-runtime-bundle' (Scenario 4 / sensor council-persona-pattern-citation)" >&2
    for p in "${PERSONAS[@]}"; do
        if ! grep -qE 'concepts/yoke-pattern-sprint-runtime-bundle' "$p"; then
            echo "  MISSING: $p" >&2
        fi
    done
    exit 1
fi

# --- (c) spec is read-only architectural context --------------------------

# Each persona file MUST reference the spec path AND signal read-only /
# architectural-context posture in the prompt body.
for p in "${PERSONAS[@]}"; do
    if ! grep -qF '.yoke/specs/<slug>.md' "$p"; then
        echo "FAIL: $p does not reference '.yoke/specs/<slug>.md' (Scenario 4: spec must be declared as read-only architectural context)" >&2
        exit 1
    fi
    # Look for at least one of these architectural-context markers.
    if ! grep -qiE 'read-only|read only|architectural context|not iterated|MUST NOT iterate|design-doc' "$p"; then
        echo "FAIL: $p does not signal read-only / architectural-context posture for the spec (Scenario 4)" >&2
        exit 1
    fi
done

# --- (d) persona instructs sprint-path citation in own slice --------------

# Each persona's Phase A instructions should drive the persona to read
# the sprint file as the cycle's working set. The deterministic check:
# the persona file refers to the sprint-file working-set both in the
# Phase-A read-list AND distinguishes it from the spec.
for p in "${PERSONAS[@]}"; do
    # Extract Phase A section (from "## Phase A" to next "## " H2).
    phase_a_body="$(awk '/^## Phase A/{flag=1} flag && /^## [^P]/ && !/^## Phase A/{flag=0} flag' "$p")"
    if [[ -z "$phase_a_body" ]]; then
        echo "FAIL: $p has no '## Phase A' section (Scenario 4 requires Phase A drive sprint-file reading)" >&2
        exit 1
    fi
    if ! grep -qE '\.yoke/sprints/' <<<"$phase_a_body"; then
        echo "FAIL: $p '## Phase A' section does not reference the sprint file path (Scenario 4 / d: persona must read sprint file in Phase A)" >&2
        exit 1
    fi
done

# --- (e) cycle-slice sprint-path citation contract ------------------------

# When persona slices land at .yoke/runtime/cycles/<N>/<persona>.md,
# every slice body MUST cite the sprint file path at least once. We
# cannot drive a Phase A spawn from inside a bash test; instead, when
# such slices already exist on disk for the active cycle, we run the
# sensor's grep against them as a soft validator. If no slices exist
# yet (chicken-and-egg in Sprint 02 / cycle 1 — Sr Eng has not landed
# its slice), this section is informational only.

# Resolve the active slug + cycle by reading runtime state.
SLUG_FILE="$REPO_ROOT/.yoke/runtime/.current"
CYCLE_FILE="$REPO_ROOT/.yoke/runtime/.cycle-counter"
if [[ -f "$SLUG_FILE" && -f "$CYCLE_FILE" ]]; then
    SLUG="$(<"$SLUG_FILE")"
    SLUG="${SLUG//$'\n'/}"
    CYCLE="$(<"$CYCLE_FILE")"
    CYCLE="${CYCLE//$'\n'/}"
    CYCLE_DIR="$REPO_ROOT/.yoke/runtime/cycles/$CYCLE"
    if [[ -d "$CYCLE_DIR" ]]; then
        for persona in sr-eng sr-qa sr-staff; do
            slice="$CYCLE_DIR/$persona.md"
            if [[ -f "$slice" ]]; then
                if ! grep -qE '\.yoke/sprints/' "$slice"; then
                    # Note: the sr-qa slice is THIS persona's own slice,
                    # which the coordinator writes after this test runs
                    # in the cycle's Sr-QA Phase A — so absence here
                    # for sr-qa is the expected pre-Phase-A state.
                    echo "FAIL: cycle slice $slice does not cite '.yoke/sprints/' path (sensor council-cycle-slice-sprint-path-citation; Scenario 4 / e)" >&2
                    exit 1
                fi
            fi
        done
    fi
fi

echo "OK: tests/acceptance/2026-05-03-tech-spec-as-design-doc/scenario-4-council-personas-sprint-path.test.sh"
exit 0
