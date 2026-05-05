#!/usr/bin/env bash
# criterion: AC-001-4
#
# AC-001-4 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "Re-running `/yoke:fix` on a slug already owned by `/yoke:discover`
#    (a `.yoke/prds/<slug>.md` exists) hits FR-4's collision check
#    during slug proposal, regenerates a *semantically distinct* slug,
#    and writes the fix-spec under the new slug — never silently
#    overwrites the PRD or appends a numeric suffix."
#
# Sprint scope (s03-t04): skills/fix/SKILL.md performs slug proposal
# with FR-4 collision detection across both .yoke/prds/ and .yoke/fixes/
# directories via wm_slug_in_use.
#
# Pragmatic gating (per Sr QA cycle prompt direction):
#   The slug-collision branch fires inside the LLM dialogue and emits
#   a regenerated slug. From bash we cannot drive the LLM; we gate on
#   the binding observables:
#
#     (a) the underlying collision predicate (wm_slug_in_use) walks
#         BOTH prds/ and fixes/ — Sprint 02 already added `fixes` to
#         WM_ARCHIVE_CATEGORIES per the cycle 1+2 verdicts; this test
#         pins that property does not regress;
#     (b) the skill body documents the FR-4 collision check by name
#         and prohibits silent overwrite + numeric-suffix fallback;
#     (c) any existing on-disk corpus with both .yoke/prds/<S>.md and
#         .yoke/fixes/<S>.md sharing the same slug indicates the
#         collision check failed — flagged as a violation here as
#         a defense-in-depth scan.
#
#   Manual end-to-end recipe (recorded for human review):
#     # Pre-condition: .yoke/prds/2026-05-05-foo.md exists.
#     $ /yoke:fix "broken behaviour anchored on the foo contract"
#     # OBSERVE: dialogue surfaces FR-4 collision; proposes a
#     # semantically-distinct slug (e.g. 2026-05-05-foo-runtime-fix
#     # rather than 2026-05-05-foo-2). Materialization writes
#     # .yoke/fixes/<new-slug>.md, never overwriting the PRD.
#
# Observable conditions tested:
#   (1) skills/fix/SKILL.md exists.
#   (2) skill body documents FR-4 collision check across prds/ AND
#       fixes/ (or wm_slug_in_use invocation, which transitively walks
#       both).
#   (3) skill body forbids numeric-suffix fallback as a slug-rescue
#       mechanism — the documented behaviour is "regenerate a
#       semantically distinct slug", not "append -2".
#   (4) wm_slug_in_use walks both `prds` and `fixes` archive
#       categories (regression-guard Sprint 02's
#       WM_ARCHIVE_CATEGORIES += fixes).
#   (5) Defense-in-depth: scan the on-disk corpus and flag any slug
#       that has both .yoke/prds/<slug>.md AND .yoke/fixes/<slug>.md
#       — no such collision should exist if the skill honors AC-001-4.

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
PATHS_LIB="$REPO_ROOT/lib/working-memory/paths.sh"

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
# Case (2) — collision check is documented.
#
# Either the skill body cites wm_slug_in_use (which transitively checks
# both prds/ and fixes/) OR it cites both directories explicitly.
# ---------------------------------------------------------------------------
if grep -qE 'wm_slug_in_use|collision' <<<"$SKILL_BODY" && \
   ( grep -q 'wm_slug_in_use' <<<"$SKILL_BODY" || \
     ( grep -qE '\.yoke/prds' <<<"$SKILL_BODY" && grep -qE '\.yoke/fixes' <<<"$SKILL_BODY" ) ); then
  pass "(2) skills/fix/SKILL.md documents FR-4 collision check (wm_slug_in_use or prds+fixes scan)"
else
  err "(2) skills/fix/SKILL.md does NOT document FR-4 collision check across prds/ AND fixes/"
fi

# ---------------------------------------------------------------------------
# Case (3) — numeric-suffix fallback is explicitly forbidden, OR the
# skill body documents "semantically distinct" / "regenerate" as the
# rescue mechanism. Either form satisfies AC-001-4's "never appends a
# numeric suffix" half.
# ---------------------------------------------------------------------------
if grep -qiE 'semantically.distinct|regenerate.+slug|propose.+new.+slug' <<<"$SKILL_BODY"; then
  pass "(3) skills/fix/SKILL.md documents semantically-distinct slug regeneration on collision"
else
  err "(3) skills/fix/SKILL.md does NOT document semantically-distinct slug regeneration — risk of numeric-suffix fallback drift"
fi

# ---------------------------------------------------------------------------
# Case (4) — wm_slug_in_use walks both prds and fixes.
#
# Regression-guard: Sprint 02 added `fixes` to WM_ARCHIVE_CATEGORIES.
# Drift here breaks AC-001-4 silently.
# ---------------------------------------------------------------------------
if [[ ! -f "$PATHS_LIB" ]]; then
  err "(4) lib/working-memory/paths.sh is missing"
else
  # WM_ARCHIVE_CATEGORIES must include both `prds` and `fixes`. The
  # array is consumed by wm_slug_in_use's loop body.
  CATEGORIES_LINE=$(grep -E '^readonly WM_ARCHIVE_CATEGORIES=' "$PATHS_LIB" || true)
  if grep -q 'prds' <<<"$CATEGORIES_LINE" && grep -q 'fixes' <<<"$CATEGORIES_LINE"; then
    pass "(4) WM_ARCHIVE_CATEGORIES contains both 'prds' and 'fixes' — wm_slug_in_use walks both archives"
  else
    err "(4) WM_ARCHIVE_CATEGORIES missing 'prds' or 'fixes' — collision check is incomplete: '$CATEGORIES_LINE'"
  fi
fi

# ---------------------------------------------------------------------------
# Case (5) — defense-in-depth: no slug has both .yoke/prds/<slug>.md
# AND .yoke/fixes/<slug>.md on disk. Any such collision is an FR-9
# ambiguous-Phase-1-state condition AND an AC-001-4 failure.
# ---------------------------------------------------------------------------
shopt -s nullglob
PRD_FILES=("$REPO_ROOT/.yoke/prds"/*.md)
FIX_FILES=("$REPO_ROOT/.yoke/fixes"/*.md)
shopt -u nullglob

# Build a set of fix-spec slugs for O(1) lookup.
FIX_SLUGS=()
for f in "${FIX_FILES[@]}"; do
  fname=$(basename "$f" .md)
  FIX_SLUGS+=("$fname")
done

COLLISIONS=()
for p in "${PRD_FILES[@]}"; do
  pname=$(basename "$p" .md)
  for fs in "${FIX_SLUGS[@]}"; do
    if [[ "$pname" == "$fs" ]]; then
      COLLISIONS+=("$pname")
    fi
  done
done

if [[ "${#COLLISIONS[@]}" -eq 0 ]]; then
  pass "(5) no slug has both .yoke/prds/ and .yoke/fixes/ artifacts (no FR-4 / AC-001-4 collision on disk)"
else
  for c in "${COLLISIONS[@]}"; do
    err "(5) AC-001-4 collision: slug '$c' has BOTH .yoke/prds/${c}.md AND .yoke/fixes/${c}.md"
  done
fi

harness::summary
