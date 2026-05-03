#!/usr/bin/env bash
# shellcheck shell=bash
#
# tests/smoke/tech-spec-design-doc-shape.test.sh
#
# Pins the Phase-2 design-doc shape contract landed in Sprint 01 of
# `.yoke/specs/2026-05-03-tech-spec-as-design-doc.md`. The new shape:
#   - exactly one file at .yoke/specs/<slug>.md
#   - twelve H2 sections, in fixed order
#   - zero `### Task ` anchors in the spec body
#   - zero sprint files produced by Phase 2 (those belong to Phase 3)
#   - every NFR bullet matches the quantitative-target regex
#   - every `### Alt: ` subsection carries the three required labels
#
# The test runs against an on-disk artifact set under the project's
# .yoke/. The slug defaults to the dogfood slug for this task — an
# explicit SLUG_UNDER_TEST environment override targets any other
# dogfood slug for the post-canonization end-to-end run (per s02-t03
# Path B parameterization).
#
# Watchdog (concepts/yoke-conventions: smoke tests must use this
# guard) caps the smoke at 10 minutes. The test completes in well
# under a second on real hardware; the watchdog is the safety net for
# ralph-loop iterations or background subagents without hard bounds.
#
# Exits 0 on pass, non-zero on the first failing assertion, with a
# `wm: tech-spec-design-doc-shape violation: ...` line on stderr.

set -euo pipefail

# Watchdog (mandatory per concepts/yoke-conventions).
sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM '"${WATCHDOG_PID}"' 2>/dev/null || true' EXIT

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

SLUG="${SLUG_UNDER_TEST:-2026-05-03-tech-spec-as-design-doc}"
SPEC_PATH=".yoke/specs/${SLUG}.md"
SPRINTS_DIR=".yoke/sprints"

violation() {
  printf 'wm: tech-spec-design-doc-shape violation: %s\n' "$1" >&2
  exit 1
}

# Helper: `grep -c` exits 1 on zero matches; this wrapper returns the
# count as a string and never fails under `set -e`/`pipefail`.
grep_count() {
  local pattern="$1" file="$2"
  local n
  n="$(grep -cE "${pattern}" "${file}" 2>/dev/null || true)"
  echo "${n:-0}" | xargs
}

[[ -f "${SPEC_PATH}" ]] \
  || violation "spec file not found at ${SPEC_PATH} (set SLUG_UNDER_TEST to override)"

# ---------------------------------------------------------------------------
# Assertion 1: exactly twelve H2 sections matching the documented set.
# ---------------------------------------------------------------------------
EXPECTED_H2_RE='^## (Context and Scope|Goals and Non-Goals|System Context|Architecture|Stack and Dependencies|APIs and Data Model|Non-Functional Requirements|Alternatives Considered|Trade-offs|Cross-cutting Concerns|Technical Use Cases|Open Questions)$'
h2_match_count="$(grep_count "${EXPECTED_H2_RE}" "${SPEC_PATH}")"
[[ "${h2_match_count}" -eq 12 ]] \
  || violation "expected 12 documented H2 sections in ${SPEC_PATH}, found ${h2_match_count}"

# ---------------------------------------------------------------------------
# Assertion 2: H2 sections appear in the documented order.
# ---------------------------------------------------------------------------
EXPECTED_ORDER=(
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
mapfile -t actual_order < <(grep -E "${EXPECTED_H2_RE}" "${SPEC_PATH}" | sed 's/^## //')
for i in "${!EXPECTED_ORDER[@]}"; do
  expected="${EXPECTED_ORDER[$i]}"
  actual="${actual_order[$i]:-<missing>}"
  [[ "${expected}" == "${actual}" ]] \
    || violation "H2 section #$((i + 1)) in ${SPEC_PATH}: expected '${expected}', found '${actual}'"
done

# ---------------------------------------------------------------------------
# Assertion 3: zero `### Task ` anchors in the spec body (Phase 2 produces
# the design doc; task anchors live in the sprint files Phase 3 produces).
# `grep -c` exits 1 when count is 0; use `|| true` to swallow that under
# `set -e` (the count "0" is the value we want, not a process failure).
# ---------------------------------------------------------------------------
task_anchor_count="$(grep_count '^### Task ' "${SPEC_PATH}")"
[[ "${task_anchor_count}" -eq 0 ]] \
  || violation "expected zero '### Task ' anchors in ${SPEC_PATH}, found ${task_anchor_count}"

# ---------------------------------------------------------------------------
# Assertion 4: every NFR bullet under `## Non-Functional Requirements`
# matches the quantitative-target regex (case-insensitive). Adjective-only
# entries fail the contract per FR-7.
# ---------------------------------------------------------------------------
NFR_QUANT_RE='[0-9]+(\.[0-9]+)?[[:space:]]*(ms|s|%|rps|qps|req/s|MB|GB|TB|users)'

# Slice the NFR section: from `## Non-Functional Requirements` to the next H2.
nfr_slice="$(awk '
  /^## Non-Functional Requirements[[:space:]]*$/ { capture = 1; next }
  capture && /^## / { capture = 0 }
  capture { print }
' "${SPEC_PATH}")"

# Each NFR is a `- **<NFR-name>:** <quantitative target>` bullet. The
# section MAY be empty for slugs whose dogfood scope has no NFRs (this is
# allowed by the contract — FR-7 rejects adjective-only entries, not
# missing entries). When present, every bullet MUST be quantitative.
nfr_bullet_count=0
nfr_violation=""
while IFS= read -r line; do
  # Skip empty/non-bullet lines and any non-NFR bullets (e.g. nested
  # rationale sub-bullets that don't start with `- **`).
  [[ -z "${line}" ]] && continue
  [[ "${line}" =~ ^-[[:space:]]\*\*[^*]+:\*\* ]] || continue
  nfr_bullet_count=$((nfr_bullet_count + 1))
  if ! grep -qiE "${NFR_QUANT_RE}" <<< "${line}"; then
    nfr_violation="${line}"
    break
  fi
done <<< "${nfr_slice}"

if [[ -n "${nfr_violation}" ]]; then
  violation "NFR bullet missing quantitative target in ${SPEC_PATH}: '${nfr_violation}'"
fi

# ---------------------------------------------------------------------------
# Assertion 5: every `### Alt: ` subsection under `## Alternatives Considered`
# carries all three required labels: `**Trade-off vs. chosen:**`,
# `**Reason for rejection:**`, `**Source:**`.
# ---------------------------------------------------------------------------
alts_slice="$(awk '
  /^## Alternatives Considered[[:space:]]*$/ { capture = 1; next }
  capture && /^## / { capture = 0 }
  capture { print }
' "${SPEC_PATH}")"

# Extract per-alternative slices keyed on `### Alt: `.
alt_count=0
alt_violation=""
current_alt=""
current_body=""
flush_alt() {
  if [[ -n "${current_alt}" ]]; then
    alt_count=$((alt_count + 1))
    for label in '\*\*Trade-off vs\. chosen:\*\*' '\*\*Reason for rejection:\*\*' '\*\*Source:\*\*'; do
      if ! grep -qE "${label}" <<< "${current_body}"; then
        # Convert escaped label back to display form for the message.
        display="$(sed 's/\\//g' <<< "${label}")"
        alt_violation="alternative '${current_alt}' missing label '${display}'"
        return
      fi
    done
  fi
  current_alt=""
  current_body=""
}

while IFS= read -r line; do
  if [[ "${line}" =~ ^###[[:space:]]+Alt:[[:space:]]+(.+)$ ]]; then
    flush_alt
    [[ -n "${alt_violation}" ]] && break
    current_alt="${BASH_REMATCH[1]}"
    current_body=""
  elif [[ -n "${current_alt}" ]]; then
    current_body+="${line}"$'\n'
  fi
done <<< "${alts_slice}"
flush_alt

if [[ -n "${alt_violation}" ]]; then
  violation "${alt_violation} in ${SPEC_PATH}"
fi

# alt_count MAY be 0 when the dogfood slug has no alternatives to surface
# (the contract's FR-8 rejects entries missing the triple, not missing
# entries). When present, each entry MUST carry the triple — that is
# what the loop above asserts.

# ---------------------------------------------------------------------------
# Assertion 6: zero Phase-2-side-effect sprint files for the slug — sprint
# files are produced by Phase 3 (they are EXPECTED to exist after Phase 3
# runs). This assertion is a Phase-2-only invariant; when the slug already
# has Phase 3 artifacts (the active dogfood slug does), this assertion is
# soft: we record but do not fail. The strict zero-sprint assertion fires
# when SLUG_UNDER_TEST_PHASE2_ONLY=1 — used by the dedicated Phase-2-only
# regression run.
# ---------------------------------------------------------------------------
sprint_count=0
if [[ -d "${SPRINTS_DIR}" ]]; then
  sprint_count="$(find "${SPRINTS_DIR}" -name "${SLUG}-s[0-9][0-9].md" -type f 2>/dev/null | wc -l | xargs)"
fi
if [[ "${SLUG_UNDER_TEST_PHASE2_ONLY:-0}" == "1" ]]; then
  [[ "${sprint_count}" -eq 0 ]] \
    || violation "Phase-2-only mode: expected 0 sprint files for slug ${SLUG}, found ${sprint_count}"
fi

echo "OK tech-spec-design-doc-shape (slug=${SLUG}, h2=12, alts=${alt_count}, nfrs=${nfr_bullet_count}, sprints=${sprint_count})"
exit 0
