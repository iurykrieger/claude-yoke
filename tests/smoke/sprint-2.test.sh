#!/usr/bin/env bash
# tests/smoke/sprint-2.test.sh
#
# Working-memory invariants for the sprint-as-cycle migration.
#
# Three assertions guard against regressions on the post-migration
# working-memory shape:
#   1. Zero `-part-N.md` residue under `.yoke/specs/`. Any such file
#      means the legacy multi-part spec convention has been
#      reintroduced and the migration regressed.
#   2. Every legacy slug (recorded in tests/fixtures/legacy-slugs.txt)
#      has at least one `.yoke/sprints/<slug>-s<NN>.md` counterpart.
#      Drops indicate a sprint file was lost.
#   3. Post-migration line counts (per migrated file) match
#      pre-migration line counts (recorded in
#      tests/fixtures/pre-migration-line-count.txt) modulo the
#      header-reframing budget (±3 lines per file: H1 reframe +
#      blank line + `> Migrated from:` annotation block — measured
#      against the actual sprint-2 t03 reframe output, which added
#      exactly 3 lines per migrated file). Larger drift means body
#      content changed during migration.
#
# Source: .yoke/specs/2026-04-27-sprint-as-cycle.md (sprint 4 t04 of
# the sprint-as-cycle PRD). Cites concepts/yoke-pattern-memory-model.
#
# macOS-portability note: every `wc -l` count is piped through
# `xargs` to strip BSD/macOS leading whitespace before string
# comparison or arithmetic.
set -euo pipefail

# Resolve repo root regardless of where the test is invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAIL=0
fail() { echo "FAIL: $*" >&2; FAIL=1; }
pass() { echo "PASS: $*"; }

echo "--- sprint-2 working-memory invariants ---"

# ---------------------------------------------------------------------------
# Assertion 1: Zero -part-N.md residue under .yoke/specs/.
# Failure-message string anchor: "legacy -part-N.md spec files found"
# ---------------------------------------------------------------------------
parts_count="$(find .yoke/specs -name '*-part-[0-9]*.md' -type f 2>/dev/null | wc -l | xargs)"
if [[ "$parts_count" != "0" ]]; then
    fail "legacy -part-N.md spec files found under .yoke/specs/; migration regressed (count=$parts_count)"
else
    pass "zero legacy -part-N.md spec files under .yoke/specs/"
fi

# ---------------------------------------------------------------------------
# Assertion 2: Every legacy slug has a sprint counterpart.
# Failure-message string anchor: "lost its sprint counterpart"
# ---------------------------------------------------------------------------
slugs_fixture="tests/fixtures/legacy-slugs.txt"
if [[ ! -f "$slugs_fixture" ]]; then
    fail "fixture missing: $slugs_fixture"
else
    while IFS= read -r slug; do
        [[ -z "$slug" ]] && continue
        match_count="$(find .yoke/sprints -name "${slug}-s[0-9][0-9].md" -type f 2>/dev/null | wc -l | xargs)"
        if [[ "$match_count" -lt 1 ]]; then
            fail "legacy slug ${slug} lost its sprint counterpart (no .yoke/sprints/${slug}-s<NN>.md found)"
        fi
    done < "$slugs_fixture"
    [[ "$FAIL" -eq 0 ]] && pass "every legacy slug has at least one sprint counterpart"
fi

# ---------------------------------------------------------------------------
# Assertion 3: Pre/post line-count parity within ±2-line reframing budget.
# Failure-message string anchor: "content drift exceeds"
# ---------------------------------------------------------------------------
line_count_fixture="tests/fixtures/pre-migration-line-count.txt"
if [[ ! -f "$line_count_fixture" ]]; then
    fail "fixture missing: $line_count_fixture"
else
    drift_violations=0
    while IFS=' ' read -r basename pre_lines; do
        [[ -z "$basename" ]] && continue
        # Pre-migration name is `<slug>-part-N.md`; post-migration is
        # `<slug>-s<NN>.md`. Map by stripping `-part-N.md` and
        # checking sprint files for any `-s<NN>.md` post-counterpart.
        slug="${basename%-part-*.md}"
        part_n="${basename##*-part-}"; part_n="${part_n%.md}"
        printf -v sprint_n "%02d" "$part_n"
        post_path=".yoke/sprints/${slug}-s${sprint_n}.md"
        if [[ ! -f "$post_path" ]]; then
            # Already covered by assertion 2 above; skip drift check.
            continue
        fi
        post_lines="$(wc -l < "$post_path" | xargs)"
        delta=$(( post_lines - pre_lines ))
        # Allow ±3 line drift: H1 reframe + blank line + `> Migrated
        # from:` annotation. Sprint 2 t03 added exactly 3 lines per
        # migrated file; larger drift means body content changed.
        if (( delta > 3 || delta < -3 )); then
            fail "post-migration content drift exceeds reframing budget for ${post_path} (pre=${pre_lines}, post=${post_lines}, delta=${delta})"
            drift_violations=$((drift_violations + 1))
        fi
    done < "$line_count_fixture"
    [[ "$drift_violations" -eq 0 ]] && pass "post-migration line counts within ±3-line reframing budget for every migrated file"
fi

if [[ "$FAIL" -eq 0 ]]; then
    echo "--- sprint-2 invariants: ALL PASS ---"
    exit 0
else
    echo "--- sprint-2 invariants: FAILURES ABOVE ---" >&2
    exit 1
fi
