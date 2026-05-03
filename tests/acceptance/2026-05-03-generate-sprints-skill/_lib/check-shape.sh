#!/usr/bin/env bash
# tests/acceptance/2026-05-03-generate-sprints-skill/_lib/check-shape.sh
#
# QA test-infrastructure: shape-validation helper for acceptance-criteria
# fixtures. Pure-bash regex cascade. This file lives under Sr QA's
# `tests/acceptance/<contract-slug>/` lane per the council role contract
# (`agents/sr-qa.md` :: Allowed tools + Anti-scope) — it has no production
# callsite and is invoked exclusively by:
#   - tests/smoke/acceptance-criteria-shape.test.sh   (Sprint 01 task t05)
#   - tests/acceptance/2026-05-03-generate-sprints-skill/
#       scenario-05-ac-shape-smoke-green.test.sh      (Acceptance Contract
#                                                      Scenario 5 wrapper)
#
# Lineage: this helper was relocated here in cycle 1 of the council loop on
# 2026-05-03 from `lib/working-memory/check-acceptance-criteria-shape.sh`
# after Phase B classified the original placement as a slice-protocol
# violation (Sr QA wrote into Sr Eng's `lib/` lane on the basis of a
# "QA-lib carve-out" header that has no doctrine grounding). Path 1
# (move into the test tree) was the cycle-0 council-consensus
# resolution.
#
# Acceptance Contract scenarios anchored:
#   - Scenario 5: AC-shape smoke test green across three fixtures.
#
# Contract:
#   Usage:  check-shape.sh <path-to-ac-file>
#   Stdout: nothing on success; nothing on failure either.
#   Stderr: a single `wm:`-prefixed diagnostic line on failure.
#   Exit:   0 on valid, non-zero on any documented violation.
#
# Documented violations:
#   - File missing or unreadable                  -> wm: file missing or unreadable
#   - Zero `### US-` or `### UC-` headings        -> wm: no UC headings found
#   - Any task-ID string `<slug>-s<NN>-t<MM>`     -> wm: forbidden task-ID reference
#
# Heading-shape policy (post AC re-ratification 2026-05-03T10:44:11Z):
# the canonical template `templates/acceptance-criteria.md` anchors User
# Stories with `### US-<NNN>` per US-002 of the binding contract. The
# checker accepts either `### US-` or `### UC-` headings: `### US-` is
# the canonical post-re-ratification shape; `### UC-` is the legacy
# pre-re-ratification shape preserved in cycle-0 fixtures (which are
# scoped to QA test infrastructure and not user-facing).
# The stderr literal `wm: no UC headings found` is preserved verbatim
# from cycle-0 to keep the smoke / scenario-05 grep assertions stable
# (the literal is treated as an opaque diagnostic ID, not as a shape
# claim).

set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'wm: usage: %s <path>\n' "$(basename "$0")" >&2
  exit 2
fi

ac_path="$1"

if [[ ! -f "$ac_path" || ! -r "$ac_path" ]]; then
  printf 'wm: file missing or unreadable: %s\n' "$ac_path" >&2
  exit 1
fi

# Rule 1 — at least one `### US-<NNN>` or `### UC-<n>` heading.
# Match the documented header anchor at line start. `### US-` is the
# canonical post-re-ratification shape (templates/acceptance-criteria.md);
# `### UC-` is preserved for legacy fixtures.
if ! grep -q -E '^### (US|UC)-[0-9]+' "$ac_path"; then
  printf 'wm: no UC headings found in %s\n' "$ac_path" >&2
  exit 1
fi

# Rule 2 — zero forbidden task-ID strings.
# A task ID has the shape `<slug>-s<NN>-t<MM>` where <slug> is at least
# one date-prefixed token. The regex below matches a YYYY-MM-DD date
# (the canonical slug prefix) followed by any non-whitespace
# characters and then `-s<digits>-t<digits>`. This is intentionally
# narrow to avoid false positives on plain `s01` / `t02` substrings
# that may legitimately appear in prose.
if grep -q -E '[0-9]{4}-[0-9]{2}-[0-9]{2}-[A-Za-z0-9._-]+-s[0-9]+-t[0-9]+' "$ac_path"; then
  printf 'wm: forbidden task-ID reference in %s\n' "$ac_path" >&2
  exit 1
fi

# All shape rules satisfied.
exit 0
