#!/usr/bin/env bash
# Use case: /yoke:tech-spec emits an architecture-only spec —
# never authors sprint files, sprint anchors, or per-task bodies.
#
# Behaviour under test (durable):
#   The /yoke:tech-spec skill is responsible for the design doc only
#   (Phase 2 of the framework's six-phase flow). Sprint partitioning
#   and per-task bodies are produced downstream — by Phase 2.5
#   (`/yoke:generate-sprints`) — and consumed by Phase 4
#   (`/yoke:implement`). For tech-spec the binding behavioural
#   contract is:
#
#     1. The skill MUST NOT direct the LLM to write any file under
#        `.yoke/sprints/`.
#     2. The skill MUST NOT invoke / orchestrate the
#        `scaffold-sprints` helper from inside its own body
#        (scaffold-sprints belongs to a downstream phase if it
#        survives at all).
#     3. The produced spec body MUST NOT contain `### Task <slug>-s`
#        anchors — those headings live exclusively in sprint files.
#
# The test reads only the shipped skill source under
# `skills/tech-spec/`. Prose that *prohibits* writing to
# `.yoke/sprints/` (i.e. defensive language asserting the prohibition)
# is acceptable; only INSTRUCTIONAL language (Write/Edit/touch +
# `.yoke/sprints/...` paths) is a violation.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

SKILL_DIR="skills/tech-spec"
SKILL_BODY="$SKILL_DIR/SKILL.md"
FIXTURE="tests/fixtures/tech-spec/new-flow"

if [[ ! -d "$SKILL_DIR" ]]; then
  printf 'FAIL: tech-spec skill directory missing: %s\n' "$SKILL_DIR" >&2
  exit 1
fi

if [[ ! -f "$SKILL_BODY" ]]; then
  printf 'FAIL: tech-spec SKILL.md missing at %s\n' "$SKILL_BODY" >&2
  exit 1
fi

if [[ ! -d "$FIXTURE" ]]; then
  printf 'FAIL: tech-spec new-flow fixture missing: %s\n' "$FIXTURE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Block 1 — skill MUST NOT direct writes under `.yoke/sprints/`.
#
# Patterns that constitute INSTRUCTIONAL writes (violations):
#   - `Write … .yoke/sprints/…` / `Edit … .yoke/sprints/…`
#   - `touch .yoke/sprints/…`
#   - `>` / `>>` redirection into `.yoke/sprints/…`
#   - `cp … .yoke/sprints/…` / `mv … .yoke/sprints/…`
#
# Prose that NAMES the directory only to forbid writing to it (e.g.
# "Phase 2 has no business writing under `.yoke/sprints/`") is
# acceptable.
# ---------------------------------------------------------------------------
WRITE_PATTERNS='(Write|Edit|touch|cp|mv|cat\s*[><]|>>?\s*[`"'"'"']?\.yoke/sprints/|Bash:\s*[^|]*\.yoke/sprints/)'
WRITE_REFS="$(grep -RInE "${WRITE_PATTERNS}.*\.yoke/sprints/|\.yoke/sprints/[^[:space:]]+\s*<<\s*EOF" "$SKILL_DIR" 2>/dev/null || true)"
if [[ -n "$WRITE_REFS" ]]; then
  printf 'FAIL: tech-spec SKILL directs writes under .yoke/sprints/:\n' >&2
  printf '%s\n' "$WRITE_REFS" | sed 's/^/        /' >&2
  exit 1
fi
printf 'PASS: tech-spec SKILL has no write instructions targeting .yoke/sprints/\n'

# ---------------------------------------------------------------------------
# Block 2 — skill MUST NOT invoke scaffold-sprints from its own body.
#
# `scaffold-sprints` is the legacy helper that produced sprint files
# from the spec. The post-cutover tech-spec must not call it.
# (Mentions in narrative "this skill no longer calls scaffold-sprints"
# would also be acceptable, but the conservative gate is presence of
# any reference; PR #41 already removed all such references from
# main, so this gate stays strict.)
# ---------------------------------------------------------------------------
SCAFFOLD_REFS="$(grep -RIn 'scaffold-sprints' "$SKILL_DIR" 2>/dev/null || true)"
if [[ -n "$SCAFFOLD_REFS" ]]; then
  printf 'FAIL: tech-spec SKILL still references `scaffold-sprints`:\n' >&2
  printf '%s\n' "$SCAFFOLD_REFS" | sed 's/^/        /' >&2
  exit 1
fi
printf 'PASS: tech-spec SKILL has no `scaffold-sprints` references\n'

# ---------------------------------------------------------------------------
# Block 3 — fixture sanity check.
#
# The new-flow fixture under tests/fixtures/tech-spec/new-flow/ models
# the post-cutover input shape. Pre-invocation it must not pre-seed
# any sprint files (those would mask a true failure where the skill
# accidentally creates them).
# ---------------------------------------------------------------------------
WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

mkdir -p "$WORK_TREE/.yoke/sprints"
cp -R "$FIXTURE/.yoke/." "$WORK_TREE/.yoke/" 2>/dev/null || true

SPRINTS_DIR="$WORK_TREE/.yoke/sprints"
SPRINT_FILES="$(find "$SPRINTS_DIR" -maxdepth 2 -type f -name '*-s*.md' 2>/dev/null || true)"
if [[ -n "$SPRINT_FILES" ]]; then
  printf 'FAIL: new-flow fixture pre-invocation contains sprint files (fixture pollution):\n' >&2
  printf '%s\n' "$SPRINT_FILES" | sed 's/^/        /' >&2
  exit 1
fi
printf 'PASS: new-flow fixture is sprint-free pre-invocation\n'

# ---------------------------------------------------------------------------
# Block 4 — the skill body MUST NOT instruct the LLM to author
# `### Task <slug>-s<NN>-t<MM>` headings into the spec.
#
# Such headings are sprint-runtime anchors; they belong in
# `.yoke/sprints/<slug>-s*.md`, not in `.yoke/specs/<slug>.md`.
# Prose that *prohibits* such headings (e.g. "the spec carries no
# `### Task <ID>` anchors") is acceptable; we only flag instructional
# templates (the literal anchor with a placeholder slug).
#
# The strict regex matches `### Task <slug>-s<NN>-t<MM>` where slug
# is a non-trivial token (≥ 4 chars including a digit-prefixed date),
# which excludes prose like "### Task <ID>" used in narrative
# explanations.
# ---------------------------------------------------------------------------
TASK_HEAD_REFS="$(grep -nE '^### Task [0-9]{4}-[0-9]{2}-[0-9]{2}-[A-Za-z0-9._-]+-s[0-9]+(-t[0-9]+)?' "$SKILL_BODY" 2>/dev/null || true)"
if [[ -n "$TASK_HEAD_REFS" ]]; then
  printf 'FAIL: tech-spec SKILL.md authors literal `### Task <slug>-s<NN>` headings:\n' >&2
  printf '%s\n' "$TASK_HEAD_REFS" | sed 's/^/        /' >&2
  exit 1
fi
printf 'PASS: tech-spec SKILL.md has no `### Task <slug>-s<NN>` heading templates\n'

printf '\n--- Result ---\nPASS: tech-spec-emits-architecture-only\n'
exit 0
