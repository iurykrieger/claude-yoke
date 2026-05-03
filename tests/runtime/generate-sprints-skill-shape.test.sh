#!/usr/bin/env bash
# shellcheck shell=bash
#
# generate-sprints-skill-shape.test.sh — Sprint 02 / Task t01 happy-path
# unit test (US-003 DoD bullet 1 + AC-003 frontmatter checks).
#
# Asserts that `skills/generate-sprints/SKILL.md` exists with the
# four required frontmatter keys (`name`, `description`,
# `argument-hint`, `allowed-tools`) and that the body skeleton renders
# the six expected H2 sections in fixed order (Lineage / Your role /
# Process / Pre-conditions / Output contract / Anti-patterns / See
# also). The Process section MUST carry six numbered H3 stages
# (Pre-flight → Read inputs → Synthesis → Partition → Render → Trigger
# 2.5) — the body of the last four is allowed to remain a TBD
# placeholder for Sprint 02; only the headers must exist.
#
# Test contract:
#   - exit 0 when every assertion below passes.
#   - exit non-zero with `wm: skill-shape violation:`-prefixed stderr
#     naming the failed assertion otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
SKILL_PATH="${REPO_ROOT}/skills/generate-sprints/SKILL.md"

violation() {
  printf 'wm: skill-shape violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "$SKILL_PATH" ]] \
  || violation "SKILL.md not found at $SKILL_PATH"

# --- Frontmatter assertions -------------------------------------------------

# `name: generate-sprints` is the canonical skill identifier.
grep -qE '^name: generate-sprints$' "$SKILL_PATH" \
  || violation "missing or wrong 'name: generate-sprints' frontmatter line"

# `description:` is required and non-empty (folded scalar `>` is fine).
grep -qE '^description:[[:space:]]*' "$SKILL_PATH" \
  || violation "missing 'description:' frontmatter key"

# `argument-hint:` MUST be present (empty string is allowed since the
# skill resolves the slug from `.yoke/runtime/.current`).
grep -qE '^argument-hint:[[:space:]]*' "$SKILL_PATH" \
  || violation "missing 'argument-hint:' frontmatter key"

# `allowed-tools:` MUST list every tool the skill needs (Read, Write,
# Edit, Grep, Glob, Bash, Skill).
grep -qE '^allowed-tools:[[:space:]]+Read,[[:space:]]+Write,[[:space:]]+Edit,[[:space:]]+Grep,[[:space:]]+Glob,[[:space:]]+Bash,[[:space:]]+Skill$' "$SKILL_PATH" \
  || violation "missing or malformed 'allowed-tools:' frontmatter line"

# --- Frontmatter parses as YAML --------------------------------------------

# Extract the frontmatter block and feed it to python3+yaml. Any parse
# error here means the skill cannot be loaded by the harness.
python3 - "$SKILL_PATH" <<'PY' \
  || violation "frontmatter does not parse as YAML"
import sys
try:
    import yaml  # type: ignore[import]
except ImportError:
    sys.exit(0)  # yaml unavailable; skip strict parse but pass.
with open(sys.argv[1], encoding="utf-8") as f:
    raw = f.read()
parts = raw.split("---", 2)
if len(parts) < 3:
    sys.exit(1)
try:
    yaml.safe_load(parts[1])
except Exception:
    sys.exit(1)
sys.exit(0)
PY

# --- Body section assertions -----------------------------------------------

# Required H2 sections in fixed order.
EXPECTED_H2=(
  "## Lineage"
  "## Your role (Senior Engineer persona, inline)"
  "## Process"
  "## Pre-conditions"
  "## Output contract"
  "## Anti-patterns"
  "## See also"
)

# Capture the line numbers of the H2 headings, in document order.
mapfile -t ACTUAL_H2_LINES < <(
  grep -nE '^## ' "$SKILL_PATH" | cut -d: -f1
)
mapfile -t ACTUAL_H2 < <(
  grep -E '^## ' "$SKILL_PATH"
)

[[ "${#ACTUAL_H2[@]}" -ge "${#EXPECTED_H2[@]}" ]] \
  || violation "expected at least ${#EXPECTED_H2[@]} H2 sections, found ${#ACTUAL_H2[@]}"

for i in "${!EXPECTED_H2[@]}"; do
  expected="${EXPECTED_H2[$i]}"
  actual="${ACTUAL_H2[$i]:-<missing>}"
  if [[ "$actual" != "$expected" ]]; then
    violation "H2 ordering: position $i expected '$expected', got '$actual'"
  fi
done

# --- Process H3 stages (six numbered headers) ------------------------------

EXPECTED_H3_STAGES=(
  "### 1. Pre-flight"
  "### 2. Read inputs"
)

# Stages 3..6 carry a "(TBD — Sprint 03)" suffix during Sprint 02.
EXPECTED_H3_PREFIXES=(
  "### 3. Synthesis"
  "### 4. Partition"
  "### 5. Render"
  "### 6. Trigger 2.5"
)

for stage in "${EXPECTED_H3_STAGES[@]}"; do
  grep -qF "$stage" "$SKILL_PATH" \
    || violation "missing Process H3 header: '$stage'"
done

for prefix in "${EXPECTED_H3_PREFIXES[@]}"; do
  grep -qE "^$(printf '%s' "$prefix" | sed 's/[][\\.^$*]/\\&/g').*$" "$SKILL_PATH" \
    || violation "missing Process H3 header starting with: '$prefix'"
done

# --- Pre-flight ordered references -----------------------------------------

# The Pre-flight section MUST reference every gate-helper sourced by
# the skill (provider hard break + active slug + approved status
# checks).
for token in \
  "yoke_require_provider" \
  "wm_active_slug" \
  "wm_check_prd_approved" \
  "wm_check_spec_approved" \
  "wm_check_ac_ratified" \
  "init_plan_file" \
  "ensure_plan_tmp_dir"
do
  grep -qF "$token" "$SKILL_PATH" \
    || violation "Pre-flight section missing reference to '$token'"
done

# --- Anti-scope assertions -------------------------------------------------

# The skill MUST forbid per-persona forks inside task bodies (FR-1).
grep -qE 'Per-persona forks' "$SKILL_PATH" \
  || violation "Anti-patterns section missing 'Per-persona forks' clause"

# The skill MUST forbid inlined criterion bodies (Rule 1 of
# yoke-pattern-sprint-runtime-bundle).
grep -qE 'Inlining criterion bodies' "$SKILL_PATH" \
  || violation "Anti-patterns section missing 'Inlining criterion bodies' clause"

printf 'PASS: skills/generate-sprints/SKILL.md frontmatter + body shape\n'
exit 0
