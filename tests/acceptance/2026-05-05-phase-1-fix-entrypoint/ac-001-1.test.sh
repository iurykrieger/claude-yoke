#!/usr/bin/env bash
# criterion: AC-001-1
#
# AC-001-1 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "Running `/yoke:fix \"axios CVE bump to 1.6.0\"` on a clean
#    .yoke/runtime/ produces .yoke/fixes/<YYYY-MM-DD>-axios-cve-bump.md
#    (or a semantically equivalent slug) carrying `Status: approved`,
#    `scope_caution:` (empty when 4/4 narrowness proxies pass), and the
#    PRD FR-7 section ordering, with `wm_active_slug` returning the
#    same slug."
#
# Sprint scope (s03-t03 + s03-t04): templates/fix.md is authored with
# the FR-7 section ordering and mandatory scope_caution: frontmatter
# field; skills/fix/SKILL.md materializes a fix-spec from that template
# and calls wm_set_active on completion.
#
# Pragmatic gating (per Sr QA cycle prompt direction):
#   /yoke:fix is an LLM-driven dialogue skill — driving it from a bash
#   test would require a Claude Code harness that is non-trivial to
#   reproduce from CI. The binding judgment is what an outside observer
#   sees AFTER a happy-path invocation: the materialized artifact's
#   shape, frontmatter, section ordering, and the `.current` pointer.
#   This test gates on those observables against:
#
#     (a) the template surface (templates/fix.md) — every fix-spec is
#         a hydration of this template, so the template's own shape
#         IS the AC-001-1 contract for new fix-specs;
#     (b) any existing .yoke/fixes/<slug>.md materialization (when the
#         repo has accumulated real fix-specs from past runs);
#     (c) the skill body's documented invocation surface — the skill
#         must reference templates/fix.md as the hydration source and
#         must call wm_set_active on completion.
#
#   Manual end-to-end recipe (recorded for human review, NOT automated
#   here):
#     $ rm -f .yoke/runtime/.current
#     $ /yoke:fix "axios CVE bump to 1.6.0"
#     # work through the dialogue (4/4 readiness should skip dialogue)
#     # select option 1 (approve_and_continue) at the menu
#     $ test -f .yoke/fixes/2026-05-05-axios-cve-bump.md
#     $ grep '^scope_caution:' .yoke/fixes/2026-05-05-axios-cve-bump.md
#     $ grep '^Status: approved' .yoke/fixes/2026-05-05-axios-cve-bump.md
#     $ wm_active_slug   # echoes 2026-05-05-axios-cve-bump
#
# Observable conditions tested:
#   (1) templates/fix.md exists.
#   (2) templates/fix.md frontmatter declares the mandatory
#       `scope_caution:` field with documented value space.
#   (3) templates/fix.md carries the PRD FR-7 section ordering verbatim.
#   (4) templates/fix.md frontmatter declares `Status:` (the literal
#       string `approved` is set at materialization time, not at
#       template authoring time — Status: <approved|draft> is the
#       templated form per templates/prd.md precedent).
#   (5) Every materialized fix-spec already on disk under
#       .yoke/fixes/<slug>.md (if any) carries `Status: approved` and
#       a `scope_caution:` key in its frontmatter.
#   (6) skills/fix/SKILL.md exists and references templates/fix.md
#       as the materialization source, plus calls wm_set_active.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

TEMPLATE="$REPO_ROOT/templates/fix.md"
SKILL="$REPO_ROOT/skills/fix/SKILL.md"

# ---------------------------------------------------------------------------
# Case (1) — templates/fix.md exists.
# ---------------------------------------------------------------------------
if [[ -f "$TEMPLATE" ]]; then
  pass "(1) templates/fix.md exists"
else
  err "(1) templates/fix.md is missing — Sr Eng s03-t03 deliverable"
  harness::summary
fi

TEMPLATE_BODY="$(cat "$TEMPLATE")"

# ---------------------------------------------------------------------------
# Case (2) — frontmatter carries `scope_caution:` field.
#
# Documented value space: empty | component-breadth | contract-shape |
# trigger-specificity | surface-containment. The template authors the
# field with a placeholder; what matters here is the key's presence.
# Yoke's Phase-1 templates use blockquote-style metadata (`> Status:`,
# `> scope_caution:`) per the templates/prd.md precedent, so we accept
# both bare and blockquote-prefixed forms.
# ---------------------------------------------------------------------------
if grep -qE '^(>[[:space:]]*)?scope_caution:' <<<"$TEMPLATE_BODY"; then
  pass "(2) templates/fix.md frontmatter declares 'scope_caution:' field"
else
  err "(2) templates/fix.md frontmatter does NOT declare 'scope_caution:' field"
fi

# ---------------------------------------------------------------------------
# Case (3) — PRD FR-7 section ordering.
#
# PRD FR-7 mandates this order:
#   Title (H1), Generated-by + Status metadata + scope_caution, Introduction,
#   What Broke, Reproduction / Trigger, Expected Behavior, Observed Behavior,
#   Blast Radius, Root-Cause Hypothesis (optional), Functional Requirements,
#   Non-Goals (Out of Scope), Risks, Regression Surface (optional),
#   Open Questions.
#
# This case asserts the order of the H2 headings that appear in the
# template (excluding optional sections and the title H1). Optional
# sections (Root-Cause Hypothesis, Regression Surface) are tolerated
# but if present must appear in the documented position.
# ---------------------------------------------------------------------------
H2_ORDER=$(awk '/^## / { sub(/^## /, ""); print }' "$TEMPLATE")

# Strip optional sections so the core sequence is comparable. Per
# Sr Staff heavy question 4, optional headings MUST be present in the
# template as "(optional)" placeholders (so authors know where to add
# the content), so we strip both the bare and "(optional)"-suffixed
# variants.
CORE_SEQUENCE=$(printf '%s\n' "$H2_ORDER" | grep -vE '^(Root-Cause Hypothesis|Regression Surface)( \(optional\))?$' || true)

# The mandatory order (lower-bound: every fix-spec MUST carry these
# sections in this order; deviations from this list are AC violations).
EXPECTED_CORE=$(cat <<'EOF'
Introduction
What Broke
Reproduction / Trigger
Expected Behavior
Observed Behavior
Blast Radius
Functional Requirements
Non-Goals (Out of Scope)
Risks
Open Questions
EOF
)

if [[ "$CORE_SEQUENCE" == "$EXPECTED_CORE" ]]; then
  pass "(3) templates/fix.md core H2 sequence matches PRD FR-7 ordering verbatim"
else
  # Render the diff in the failure for Sr Eng réplica.
  err "(3) templates/fix.md H2 sequence does NOT match PRD FR-7 — got: $(printf '%s' "$CORE_SEQUENCE" | tr '\n' '|') ; expected: $(printf '%s' "$EXPECTED_CORE" | tr '\n' '|')"
fi

# ---------------------------------------------------------------------------
# Case (4) — frontmatter declares Status. Same blockquote-tolerant
# match shape as Case (2) per templates/prd.md precedent.
# ---------------------------------------------------------------------------
if grep -qE '^(>[[:space:]]*)?Status:' <<<"$TEMPLATE_BODY"; then
  pass "(4) templates/fix.md frontmatter declares 'Status:' field"
else
  err "(4) templates/fix.md frontmatter does NOT declare 'Status:' field"
fi

# ---------------------------------------------------------------------------
# Case (5) — every materialized fix-spec on disk carries the required
# frontmatter keys. A no-op pass when no fix-spec has been materialized
# yet.
# ---------------------------------------------------------------------------
shopt -s nullglob
FIX_SPECS=("$REPO_ROOT/.yoke/fixes"/*.md)
shopt -u nullglob

if [[ "${#FIX_SPECS[@]}" -eq 0 ]]; then
  pass "(5) no materialized fix-specs under .yoke/fixes/ yet — vacuously satisfied"
else
  VIOLATIONS=()
  for fix in "${FIX_SPECS[@]}"; do
    rel="${fix#$REPO_ROOT/}"
    if ! grep -qE '^(>[[:space:]]*)?scope_caution:' "$fix"; then
      VIOLATIONS+=("$rel: missing scope_caution: key")
    fi
    if ! grep -qE '^(>[[:space:]]*)?Status:[[:space:]]*approved' "$fix"; then
      VIOLATIONS+=("$rel: Status: is not 'approved'")
    fi
  done
  if [[ "${#VIOLATIONS[@]}" -eq 0 ]]; then
    pass "(5) all ${#FIX_SPECS[@]} materialized fix-spec(s) under .yoke/fixes/ carry Status: approved AND scope_caution:"
  else
    for v in "${VIOLATIONS[@]}"; do
      err "(5) materialized fix-spec violation: $v"
    done
  fi
fi

# ---------------------------------------------------------------------------
# Case (6) — skills/fix/SKILL.md references the template and calls
# wm_set_active on completion (the binding link between the skill body
# and the wm_active_slug return value half of AC-001-1).
# ---------------------------------------------------------------------------
if [[ ! -f "$SKILL" ]]; then
  err "(6) skills/fix/SKILL.md is missing — Sr Eng s03-t04 deliverable"
else
  SKILL_BODY="$(cat "$SKILL")"
  ISSUES=()
  if ! grep -q "templates/fix.md" <<<"$SKILL_BODY"; then
    ISSUES+=("does not reference templates/fix.md as materialization source")
  fi
  if ! grep -qE 'wm_set_active' <<<"$SKILL_BODY"; then
    ISSUES+=("does not call wm_set_active (wm_active_slug return path is not wired)")
  fi
  if ! grep -qE 'wm_fix_path' <<<"$SKILL_BODY"; then
    ISSUES+=("does not call wm_fix_path (artifact materialization path is not wired)")
  fi
  if [[ "${#ISSUES[@]}" -eq 0 ]]; then
    pass "(6) skills/fix/SKILL.md references templates/fix.md AND calls wm_set_active AND calls wm_fix_path"
  else
    for issue in "${ISSUES[@]}"; do
      err "(6) skills/fix/SKILL.md $issue"
    done
  fi
fi

harness::summary
