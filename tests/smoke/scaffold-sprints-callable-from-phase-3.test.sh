#!/usr/bin/env bash
# shellcheck shell=bash
#
# tests/smoke/scaffold-sprints-callable-from-phase-3.test.sh
#
# Pins the Phase-3 invocation contract for
# `lib/working-memory/scaffold-sprints.sh`. After Sprint 01 of the
# tech-spec-as-design-doc PRD, the script is invoked from
# `/yoke:acceptance-contract` (Stage B.2) — not from `/yoke:tech-spec`.
# Its body is unchanged: a single-argument script that takes a markdown
# file containing `### Sprint <NN> — <name>` headings and creates one
# empty sprint file per heading at `.yoke/sprints/<slug>-s<NN>.md`,
# seeded from `templates/sprint.md`.
#
# This smoke exercises the script end-to-end against a synthetic sprint
# plan markdown buffer carrying three `### Sprint <NN> — <name>`
# headings. It runs in an isolated tempdir cd'd at the start (so the
# script's `WM_ROOT` resolution writes to the tempdir's `.yoke/`, not
# the repo's). Asserts:
#   - script exit code 0
#   - exactly three sprint files materialized at .yoke/sprints/
#   - each file carries the five-H2 sprint skeleton from
#     templates/sprint.md
#
# Watchdog (mandatory per concepts/yoke-conventions) caps the smoke at
# 10 minutes.
#
# Exits 0 on pass, non-zero on the first failing assertion, with a
# `wm: scaffold-sprints-callable-from-phase-3 violation: ...` line on
# stderr.

set -euo pipefail

# Watchdog (mandatory per concepts/yoke-conventions).
sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM '"${WATCHDOG_PID}"' 2>/dev/null || true' EXIT

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
SCAFFOLD_SH="${REPO_ROOT}/lib/working-memory/scaffold-sprints.sh"

violation() {
  printf 'wm: scaffold-sprints-callable-from-phase-3 violation: %s\n' "$1" >&2
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

[[ -x "${SCAFFOLD_SH}" || -f "${SCAFFOLD_SH}" ]] \
  || violation "scaffold-sprints.sh not found at ${SCAFFOLD_SH}"

# ---------------------------------------------------------------------------
# Tempdir setup. We need a fresh `.yoke/` rooted at the tempdir so the
# script's `WM_ROOT` (resolved by lib/working-memory/paths.sh) writes
# sprint files there instead of into the repo. We export `YOKE_PROJECT_ROOT`
# so paths.sh can pick it up; the script also chdirs there before running.
# ---------------------------------------------------------------------------
TMPDIR_ROOT="$(mktemp -d -t scaffold-sprints-smoke.XXXXXXXX)"
trap '
  kill -TERM '"${WATCHDOG_PID}"' 2>/dev/null || true
  rm -rf "'"${TMPDIR_ROOT}"'" 2>/dev/null || true
' EXIT

mkdir -p "${TMPDIR_ROOT}/.yoke/specs"
mkdir -p "${TMPDIR_ROOT}/.yoke/sprints"

# ---------------------------------------------------------------------------
# Synthetic spec buffer with three `### Sprint <NN> — <name>` headings.
# The slug must satisfy the working-memory slug regex (YYYY-MM-DD-kebab).
# The script extracts the slug from the spec basename (strips `.md`).
# ---------------------------------------------------------------------------
SYNTH_SLUG="2026-05-03-smoke-scaffold-sprints"
SPEC_PATH="${TMPDIR_ROOT}/.yoke/specs/${SYNTH_SLUG}.md"

cat > "${SPEC_PATH}" <<'EOF'
# Spec: synthetic smoke fixture

> Synthetic input for tests/smoke/scaffold-sprints-callable-from-phase-3.test.sh

## Sprints

### Sprint 1 — synthetic alpha
**Delivery objective:** scaffold target alpha.

### Sprint 2 — synthetic bravo
**Delivery objective:** scaffold target bravo.

### Sprint 3 — synthetic charlie
**Delivery objective:** scaffold target charlie.
EOF

# ---------------------------------------------------------------------------
# Run the script in a subshell that has cwd = tempdir. The script resolves
# `WM_ROOT` via lib/working-memory/paths.sh; that helper picks up the
# project root from cwd by default.
# ---------------------------------------------------------------------------
(
  cd "${TMPDIR_ROOT}"
  bash "${SCAFFOLD_SH}" "${SPEC_PATH}"
) || violation "scaffold-sprints.sh exited non-zero against synthetic 3-sprint spec"

# ---------------------------------------------------------------------------
# Assertion 1: exactly three sprint files materialized at
# <tempdir>/.yoke/sprints/<slug>-s<NN>.md.
# ---------------------------------------------------------------------------
mapfile -t sprint_files < <(find "${TMPDIR_ROOT}/.yoke/sprints" -name "${SYNTH_SLUG}-s[0-9][0-9].md" -type f 2>/dev/null | sort)
sprint_count=${#sprint_files[@]}
[[ "${sprint_count}" -eq 3 ]] \
  || violation "expected exactly 3 sprint files materialized, found ${sprint_count}"

# ---------------------------------------------------------------------------
# Assertion 2: each file carries the five-H2 sprint skeleton from
# templates/sprint.md (Sprint objective, Sprint DoD, Tasks, Functional
# acceptance criteria, Sensors).
# ---------------------------------------------------------------------------
EXPECTED_H2_RE='^## (Sprint objective|Sprint DoD|Tasks|Functional acceptance criteria|Sensors)$'
EXPECTED_PADDED_NUMS=(01 02 03)

for i in "${!sprint_files[@]}"; do
  sprint_file="${sprint_files[$i]}"
  expected_padded="${EXPECTED_PADDED_NUMS[$i]}"
  expected_path="${TMPDIR_ROOT}/.yoke/sprints/${SYNTH_SLUG}-s${expected_padded}.md"
  [[ "${sprint_file}" == "${expected_path}" ]] \
    || violation "sprint file #$((i + 1)): expected '${expected_path}', found '${sprint_file}'"

  h2_count="$(grep_count "${EXPECTED_H2_RE}" "${sprint_file}")"
  [[ "${h2_count}" -eq 5 ]] \
    || violation "${sprint_file}: expected 5 H2 sections from templates/sprint.md, found ${h2_count}"

  # Frontmatter slug substitution must have happened (templates/sprint.md
  # carries `slug: <slug>` placeholder; scaffold-sprints.sh substitutes it).
  grep -qE "^slug: ${SYNTH_SLUG}\$" "${sprint_file}" \
    || violation "${sprint_file}: frontmatter 'slug:' did not interpolate to '${SYNTH_SLUG}'"
done

echo "OK scaffold-sprints-callable-from-phase-3 (sprints=${sprint_count}, slug=${SYNTH_SLUG})"
exit 0
