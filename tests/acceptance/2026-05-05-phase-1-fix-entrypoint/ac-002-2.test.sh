#!/usr/bin/env bash
# criterion: AC-002-2
#
# AC-002-2 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "Running `/yoke:fix \"extract notification logic from the user
#    service into a separate module\"` (3/4 narrowness — passes
#    contract / trigger / surface but soft-fails component-breadth)
#    produces a fix-spec carrying `scope_caution: component-breadth`
#    in its frontmatter, exit-code 0, and the standard Trigger 1
#    surface."
#
# Sprint scope (s03-t03 + s03-t04): templates/fix.md frontmatter
# carries the mandatory scope_caution: field; skills/fix/SKILL.md
# writes the proxy-id into that field on 3/4 narrowness.
#
# Pragmatic gating (per Sr QA cycle prompt direction):
#   The 3/4-narrowness branch fires inside the LLM dialogue. From bash
#   we cannot exercise the dialogue. The binding judgment is:
#     (a) the template's scope_caution: field accepts the four proxy
#         identifiers in its documented value space (component-breadth,
#         contract-shape, trigger-specificity, surface-containment);
#     (b) the persona body documents the 3/4 → write-proxy-id branch;
#     (c) the persona body lists `component-breadth` as a valid
#         scope_caution value;
#     (d) any existing 3/4-narrowness fix-spec on disk carries the
#         expected scope_caution value (defense-in-depth).
#
#   Manual end-to-end recipe (recorded for human review):
#     $ /yoke:fix "extract notification logic from the user service into a separate module"
#     # OBSERVE: dialogue completes, exit code 0, materialized
#     # fix-spec carries `scope_caution: component-breadth`, Trigger 1
#     # approval menu rendered.
#     $ grep '^scope_caution: component-breadth' .yoke/fixes/<slug>.md
#     $ echo $?  # 0
#
# Observable conditions tested:
#   (1) skills/fix/SKILL.md exists.
#   (2) persona body documents the 3/4 → write `scope_caution:
#       <proxy-id>` branch.
#   (3) persona body documents the four valid scope_caution values
#       (component-breadth / contract-shape / trigger-specificity /
#       surface-containment).
#   (4) templates/fix.md exists.
#   (5) templates/fix.md frontmatter declares scope_caution: with a
#       comment / placeholder enumerating the four proxy ids (or the
#       skill body documents them — either form is acceptable, but
#       at least ONE surface MUST list the value space verbatim).
#   (6) Defense-in-depth: any existing fix-spec under .yoke/fixes/
#       with a non-empty scope_caution: value carries one of the
#       four documented proxy ids (no junk values).

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

SKILL="$REPO_ROOT/skills/fix/SKILL.md"
TEMPLATE="$REPO_ROOT/templates/fix.md"

PROXY_IDS=("component-breadth" "contract-shape" "trigger-specificity" "surface-containment")

# ---------------------------------------------------------------------------
# Case (1) — skills/fix/SKILL.md exists.
# ---------------------------------------------------------------------------
if [[ -f "$SKILL" ]]; then
  pass "(1) skills/fix/SKILL.md exists"
else
  err "(1) skills/fix/SKILL.md is missing — Sr Eng s03-t04 deliverable"
  harness::summary
fi

SKILL_BODY="$(cat "$SKILL")"

# ---------------------------------------------------------------------------
# Case (2) — 3/4 → write `scope_caution: <proxy-id>` branch is
# documented in the skill body.
# ---------------------------------------------------------------------------
if grep -qE '3/4|three.+four' <<<"$SKILL_BODY" && \
   grep -q 'scope_caution' <<<"$SKILL_BODY"; then
  pass "(2) persona body documents the 3/4-narrowness → scope_caution: <proxy-id> branch"
else
  err "(2) persona body does NOT document the 3/4-narrowness → scope_caution: <proxy-id> branch"
fi

# ---------------------------------------------------------------------------
# Case (3) — all four proxy ids appear in the skill body.
# ---------------------------------------------------------------------------
MISSING=()
for pid in "${PROXY_IDS[@]}"; do
  if ! grep -qF "$pid" <<<"$SKILL_BODY"; then
    MISSING+=("$pid")
  fi
done

if [[ "${#MISSING[@]}" -eq 0 ]]; then
  pass "(3) persona body lists all four proxy ids (component-breadth / contract-shape / trigger-specificity / surface-containment)"
else
  err "(3) persona body missing proxy ids: ${MISSING[*]}"
fi

# ---------------------------------------------------------------------------
# Case (4) — templates/fix.md exists.
# ---------------------------------------------------------------------------
if [[ -f "$TEMPLATE" ]]; then
  pass "(4) templates/fix.md exists"
else
  err "(4) templates/fix.md is missing — Sr Eng s03-t03 deliverable"
fi

# ---------------------------------------------------------------------------
# Case (5) — value space documented somewhere reachable from the
# template (template comment, frontmatter comment, or skill body).
#
# The skill body Case (3) check already demonstrates the proxy ids
# appear in the skill; this case asserts the same enumeration is
# discoverable on the template surface itself for human authors who
# read templates/fix.md without reading the skill.
# ---------------------------------------------------------------------------
if [[ -f "$TEMPLATE" ]]; then
  TEMPLATE_BODY="$(cat "$TEMPLATE")"
  TEMPLATE_LISTS_ALL=1
  for pid in "${PROXY_IDS[@]}"; do
    if ! grep -qF "$pid" <<<"$TEMPLATE_BODY"; then
      TEMPLATE_LISTS_ALL=0
      break
    fi
  done
  if [[ "$TEMPLATE_LISTS_ALL" -eq 1 ]]; then
    pass "(5) templates/fix.md surfaces all four proxy ids (template-anchored value-space documentation)"
  else
    err "(5) templates/fix.md does NOT enumerate all four proxy ids — template-anchored value space incomplete"
  fi
fi

# ---------------------------------------------------------------------------
# Case (6) — defense-in-depth: any non-empty scope_caution: value on
# disk is one of the four proxy ids.
# ---------------------------------------------------------------------------
shopt -s nullglob
FIX_SPECS=("$REPO_ROOT/.yoke/fixes"/*.md)
shopt -u nullglob

JUNK=()
for fix in "${FIX_SPECS[@]}"; do
  rel="${fix#$REPO_ROOT/}"
  # Extract the scope_caution: value (everything after the colon, trim).
  caution_line=$(grep -E '^scope_caution:' "$fix" | head -1 || true)
  if [[ -z "$caution_line" ]]; then
    continue
  fi
  caution_val="${caution_line#scope_caution:}"
  caution_val="${caution_val// /}"
  caution_val="${caution_val//\"/}"
  caution_val="${caution_val//\'/}"
  if [[ -z "$caution_val" ]]; then
    continue  # empty is a valid value (4/4 narrowness pass)
  fi
  ok=0
  for pid in "${PROXY_IDS[@]}"; do
    if [[ "$caution_val" == "$pid" ]]; then
      ok=1
      break
    fi
  done
  if [[ "$ok" -eq 0 ]]; then
    JUNK+=("$rel: scope_caution='$caution_val' is not in the documented value space")
  fi
done

if [[ "${#FIX_SPECS[@]}" -eq 0 ]]; then
  pass "(6) no materialized fix-specs to scan for scope_caution junk values — vacuously satisfied"
elif [[ "${#JUNK[@]}" -eq 0 ]]; then
  pass "(6) all ${#FIX_SPECS[@]} materialized fix-spec(s) carry valid scope_caution values"
else
  for j in "${JUNK[@]}"; do
    err "(6) junk scope_caution value: $j"
  done
fi

harness::summary
