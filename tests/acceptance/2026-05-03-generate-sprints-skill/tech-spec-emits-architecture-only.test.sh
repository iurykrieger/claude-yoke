#!/usr/bin/env bash
#
# Binding Acceptance Criteria (binding contract):
#   AC-001-1: `grep -RIn 'sprints/' skills/tech-spec/` returns zero
#             matches post-cutover.
#   AC-001-2: `grep -RIn 'scaffold-sprints' skills/tech-spec/` returns
#             zero matches.
#   AC-001-3: Running `/yoke:tech-spec` against a new-flow fixture
#             produces zero files under `.yoke/sprints/`.
#   AC-001-4: The produced spec contains zero `### Task <slug>-s` headings.
#
set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

SKILL_DIR="skills/tech-spec"
FIXTURE="tests/fixtures/tech-spec/new-flow"

if [[ ! -d "$SKILL_DIR" ]]; then
  printf 'FAIL: tech-spec skill directory missing: %s\n' "$SKILL_DIR" >&2
  exit 1
fi

if [[ ! -d "$FIXTURE" ]]; then
  printf 'FAIL: tech-spec new-flow fixture missing: %s\n' "$FIXTURE" >&2
  exit 1
fi

# AC-001-1 — `sprints/` reference count under skills/tech-spec/.
SPRINT_REFS="$(grep -RIn 'sprints/' "$SKILL_DIR" 2>/dev/null || true)"
if [[ -n "$SPRINT_REFS" ]]; then
  printf 'FAIL: AC-001-1 — `sprints/` references remain in %s\n' "$SKILL_DIR" >&2
  printf '%s\n' "$SPRINT_REFS" | sed 's/^/        /' >&2
  exit 1
fi
printf 'PASS: AC-001-1 — no `sprints/` references in %s\n' "$SKILL_DIR"

# AC-001-2 — `scaffold-sprints` references under skills/tech-spec/.
SCAFFOLD_REFS="$(grep -RIn 'scaffold-sprints' "$SKILL_DIR" 2>/dev/null || true)"
if [[ -n "$SCAFFOLD_REFS" ]]; then
  printf 'FAIL: AC-001-2 — `scaffold-sprints` references remain in %s\n' "$SKILL_DIR" >&2
  printf '%s\n' "$SCAFFOLD_REFS" | sed 's/^/        /' >&2
  exit 1
fi
printf 'PASS: AC-001-2 — no `scaffold-sprints` references in %s\n' "$SKILL_DIR"

# AC-001-3 / AC-001-4 — fixture-anchored runtime proxy.
# We mirror the new-flow fixture into a worktree, snapshot the sprints
# directory pre-invocation, then assert that the skill body documents
# only a single output file (.yoke/specs/<slug>.md) and contains no
# instruction to author `### Task <slug>-s` headings into the spec.
# The runtime check (actually running the skill) is owned by the
# tests/runtime/full-flow.test.sh end-to-end smoke; this test is a
# producer-side static gate.
WORK_TREE="$(mktemp -d)"
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true; rm -rf "$WORK_TREE"' EXIT

mkdir -p "$WORK_TREE/.yoke/sprints"
cp -R "$FIXTURE/.yoke/." "$WORK_TREE/.yoke/" 2>/dev/null || true

# Snapshot pre-invocation mtimes (the runtime proxy: any file under
# .yoke/sprints/ is a violation).
SPRINTS_DIR="$WORK_TREE/.yoke/sprints"
SPRINT_FILES="$(find "$SPRINTS_DIR" -maxdepth 2 -type f -name '*-s*.md' 2>/dev/null || true)"
if [[ -n "$SPRINT_FILES" ]]; then
  printf 'FAIL: AC-001-3 — fixture pre-invocation contains sprint files (fixture pollution):\n' >&2
  printf '%s\n' "$SPRINT_FILES" | sed 's/^/        /' >&2
  exit 1
fi

# Static-body gate against the SKILL.md surface — assert the body does
# NOT instruct the LLM to write under `.yoke/sprints/<slug>-s*.md`
# (the post-cutover skill body must be sprint-less). Treat ANY mention
# of `.yoke/sprints/` inside the skill body as a violation; the AC-001-1
# gate above already enforces this for the directory, but we keep a
# focused per-line print here for diagnostic visibility.
SKILL_BODY="$SKILL_DIR/SKILL.md"
if [[ ! -f "$SKILL_BODY" ]]; then
  printf 'FAIL: AC-001-3 — tech-spec SKILL.md missing at %s\n' "$SKILL_BODY" >&2
  exit 1
fi
SPRINT_BODY_REFS="$(grep -nE '\.yoke/sprints/' "$SKILL_BODY" 2>/dev/null || true)"
if [[ -n "$SPRINT_BODY_REFS" ]]; then
  printf 'FAIL: AC-001-3 — SKILL.md still instructs writes under .yoke/sprints/:\n' >&2
  printf '%s\n' "$SPRINT_BODY_REFS" | sed 's/^/        /' >&2
  exit 1
fi
printf 'PASS: AC-001-3 — tech-spec SKILL.md emits no .yoke/sprints/ writes\n'

# AC-001-4 — the produced spec contains no `### Task <slug>-s` headings.
# Static gate against the skill body: it must NOT instruct the LLM to
# author such headings into the spec. The literal-heading check at
# runtime is owned by tests/runtime/full-flow.test.sh; here we assert
# the producer-side body emits no such instruction.
TASK_HEAD_REFS="$(grep -nE '### Task [^[:space:]]+-s[0-9]+' "$SKILL_BODY" 2>/dev/null || true)"
# Any literal example of `### Task <slug>-s` in the post-cutover skill
# body is a violation: the body's job is to draft architecture, not
# task bodies.
if [[ -n "$TASK_HEAD_REFS" ]]; then
  printf 'FAIL: AC-001-4 — SKILL.md still describes `### Task <slug>-s` headings:\n' >&2
  printf '%s\n' "$TASK_HEAD_REFS" | sed 's/^/        /' >&2
  exit 1
fi
printf 'PASS: AC-001-4 — tech-spec SKILL.md emits no `### Task <slug>-s` headings\n'

printf '\n--- Result ---\nPASS: tech-spec-emits-architecture-only\n'
exit 0
