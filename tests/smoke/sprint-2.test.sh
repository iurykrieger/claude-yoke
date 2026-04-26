#!/bin/bash
# tests/smoke/sprint-2.test.sh
#
# Sprint 2 smoke test — validates the spec-phase artifacts shipped in
# v0.2.0 and refreshed in v1.1.0 (skills-only spec phase, no subagent
# spawn).
#
# Pre-Sprint-6: this test does NOT invoke any ralph loop. External
# `timeout` is therefore not strictly required, but use one in CI as a
# precaution (e.g. `timeout 600 bash tests/smoke/sprint-2.test.sh`).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 2 smoke ---"

# 1. SKILL.md files exist with valid frontmatter (name + description)
for skill in discover tech-spec ask; do
  f="skills/${skill}/SKILL.md"
  if [ ! -f "$f" ]; then
    err "missing $f"
    continue
  fi
  if awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$f"; then
    pass "$f frontmatter valid"
  else
    err "$f missing name/description in frontmatter"
  fi
done

# 2. v1.1 — spec-phase skills do NOT include Task in allowed-tools
#    (DoD #1 of runtime-only-agents-part-2: skills deliberate; subagents adapt).
#    /yoke:discover and /yoke:tech-spec drive their dialogues inline.
for skill in discover tech-spec; do
  f="skills/${skill}/SKILL.md"
  allowed_line=$(awk '/^allowed-tools:/{print; exit}' "$f" || true)
  if [ -z "$allowed_line" ]; then
    err "$f missing allowed-tools field"
  elif echo "$allowed_line" | grep -qw "Task"; then
    err "$f allowed-tools includes Task — should be inline (no subagent spawn): $allowed_line"
  else
    pass "$f allowed-tools excludes Task (skill-only)"
  fi
done

# 3. v1.1 — spec-phase skills embed persona inline (no "Spawn agents/...")
for skill in discover tech-spec; do
  f="skills/${skill}/SKILL.md"
  if grep -q "Spawn .agents/" "$f" || grep -q "Invoke the Generator subagent" "$f"; then
    err "$f still references subagent spawn (should be inline)"
  else
    pass "$f drops subagent-spawn references"
  fi
  if grep -qE "Generator persona|Your role .*persona" "$f"; then
    pass "$f embeds persona inline"
  else
    err "$f does not declare an inline persona"
  fi
done

# 4. PRD template has manifesto-shape sections
prd="templates/prd.md"
for section in "## Product invariants" "## Business context" "## Known constraints" "## Risks" "## Open questions"; do
  if grep -q -- "$section" "$prd"; then
    pass "$prd has '$section' section"
  else
    err "$prd missing '$section'"
  fi
done

# 5. Spec + Task templates (tech-spec-task-split Part 2):
#    - templates/tech-spec.md is deleted (superseded by spec.md + task.md)
#    - templates/spec.md carries the sprint-index sections
#    - templates/task.md carries the per-task body shape with frontmatter
[ ! -f "templates/tech-spec.md" ] \
  && pass "templates/tech-spec.md deleted (superseded by spec.md + task.md)" \
  || err "templates/tech-spec.md still present (Part 2 should have deleted it)"

spec_tpl="templates/spec.md"
for section in "## Sprints" "#### Task" "## Contracts and interfaces" "## Dependencies"; do
  if grep -q -- "$section" "$spec_tpl"; then
    pass "$spec_tpl has '$section'"
  else
    err "$spec_tpl missing '$section'"
  fi
done

task_tpl="templates/task.md"
for section in "task_id:" "## Story" "## Technical implementation" "## Validation" "## Acceptance criterion"; do
  if grep -q -- "$section" "$task_tpl"; then
    pass "$task_tpl has '$section'"
  else
    err "$task_tpl missing '$section'"
  fi
done

# 5b. /yoke:tech-spec drives the 3-stage blueprint (LLM → bash → LLM-per-task).
ts_skill="skills/tech-spec/SKILL.md"
for marker in "Stage 1" "Stage 2" "Stage 3" "scaffold-tasks.sh" "wm_spec_path" "wm_list_task_paths"; do
  if grep -q -- "$marker" "$ts_skill"; then
    pass "$ts_skill references '$marker'"
  else
    err "$ts_skill missing '$marker'"
  fi
done

# 5c. /yoke:tech-spec no longer references wm_tech_spec_path or
#     templates/tech-spec.md (Part 2 DoD #6 — scoped to this skill).
if grep -q "wm_tech_spec_path" "$ts_skill"; then
  err "$ts_skill still references wm_tech_spec_path (Part 2 should have migrated it to wm_spec_path)"
else
  pass "$ts_skill migrated off wm_tech_spec_path"
fi
if grep -q "templates/tech-spec.md" "$ts_skill"; then
  err "$ts_skill still references templates/tech-spec.md (deleted in Part 2)"
else
  pass "$ts_skill no longer references templates/tech-spec.md"
fi

# 5d. approval-menu.md carries the Tech-Spec conditional per-task block
#     (extension, not fork — per .vibeflow/patterns/human-triggers.md).
am="templates/approval-menu.md"
if grep -q "Tech-Spec-only block" "$am"; then
  pass "$am extended with Tech-Spec-only per-task summary block"
else
  err "$am missing Tech-Spec-only per-task summary block"
fi
if grep -q "task_summary" "$am"; then
  pass "$am declares task_summary input"
else
  err "$am missing task_summary input declaration"
fi

# 6. Triggers 1 + 2 surface verbatim from the skills (binding prompts).
grep -q "Trigger 1 — PRD approval" skills/discover/SKILL.md \
  && pass "/yoke:discover prints Trigger-1 binding prompt" \
  || err "/yoke:discover missing Trigger-1 binding prompt"
grep -q "Trigger 2 — Tech Spec approval" skills/tech-spec/SKILL.md \
  && pass "/yoke:tech-spec prints Trigger-2 binding prompt" \
  || err "/yoke:tech-spec missing Trigger-2 binding prompt"

# 7. /yoke:ask routing preserved in spec-phase skills
for skill in discover tech-spec; do
  f="skills/${skill}/SKILL.md"
  if grep -q "/yoke:ask" "$f"; then
    pass "$f routes canonical-memory reads through /yoke:ask"
  else
    err "$f missing /yoke:ask routing"
  fi
done

# 8. /yoke:ask is the canonical-memory adaptive read skill.
#    Part 3 of the bedrock canonical-memory port retired the standalone
#    query.sh shell-out; ask-source-agnostic-read Part 1 retired the
#    query-trace write and the .yoke/.current pre-condition. The skill
#    is now a pure source-agnostic read.
ask="skills/ask/SKILL.md"
ask_allowed=$(awk '/^allowed-tools:/{print; exit}' "$ask" || true)
if echo "$ask_allowed" | grep -qw "Task"; then
  err "/yoke:ask allowed-tools includes Task (should not spawn subagents)"
else
  pass "/yoke:ask allowed-tools excludes Task"
fi
if echo "$ask_allowed" | grep -qw "Write"; then
  err "/yoke:ask allowed-tools includes Write (skill must be pure read)"
else
  pass "/yoke:ask allowed-tools excludes Write (pure read)"
fi
grep -q "resolve-memory.sh" "$ask" \
  && pass "/yoke:ask resolves the active memory via Part 1's lib" \
  || err "/yoke:ask does not reference resolve-memory.sh"
if grep -qE 'query-traces|wm_query_trace_path|\.yoke/\.current' "$ask"; then
  err "/yoke:ask still references retired query-trace / active-task pre-condition"
else
  pass "/yoke:ask is source-agnostic (no query-trace, no active-task pre-condition)"
fi
grep -qiE 'source-agnostic|callable from any|no active-task' "$ask" \
  && pass "/yoke:ask declares its source-agnostic contract" \
  || err "/yoke:ask missing source-agnostic declaration"
grep -qiE 'never.*(clone|pull|fetch)' "$ask" \
  && pass "/yoke:ask declares the no-clone invariant (Part 3 DoD-1)" \
  || err "/yoke:ask missing no-clone invariant"

# 9. Memory resolution lib + scaffold helper from Part 1 are present
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
[ -x lib/canonical-memory/registry.sh ] || [ -f lib/canonical-memory/registry.sh ] \
  && pass "lib/canonical-memory/registry.sh present" \
  || err "registry.sh missing"
[ -x lib/canonical-memory/resolve-memory.sh ] || [ -f lib/canonical-memory/resolve-memory.sh ] \
  && pass "lib/canonical-memory/resolve-memory.sh present" \
  || err "resolve-memory.sh missing"

# 10. /yoke:ask declares the no-fabrication rule
grep -qiE 'never fabricate|do not fabricate|never invent' "$ask" \
  && pass "/yoke:ask declares no-fabrication rule" \
  || err "/yoke:ask missing no-fabrication declaration"

# 11. /yoke:ask caps entity reads at 15 (progressive disclosure)
grep -qE '15 entit|cap.*15|≤[[:space:]]*15' "$ask" \
  && pass "/yoke:ask caps entity reads at 15 (progressive disclosure)" \
  || err "/yoke:ask missing 15-entity cap"

# 11b. tech-spec-task-split cleanup invariant: no live code in skills/,
#      agents/, hooks/, lib/, or templates/ references the deprecated
#      wm_tech_spec_path helper. The migration helper
#      (lib/working-memory/migrate-tech-specs.sh) references the legacy
#      `.yoke/tech-specs/` path as its INPUT, which is acceptable.
#      Smoke tests intentionally grep for the legacy token to verify
#      the migration — those are excluded explicitly.
live_refs=$(grep -rln "wm_tech_spec_path" skills/ agents/ hooks/ lib/ templates/ 2>/dev/null \
  | grep -v "lib/working-memory/migrate-tech-specs.sh" || true)
if [ -z "$live_refs" ]; then
  pass "no live wm_tech_spec_path references (cleanup-part-3 invariant)"
else
  err "wm_tech_spec_path still referenced in: $live_refs"
fi

# 12. v1.1 anti-scope: spec-phase Generator/Validator subagent files MUST
#     NOT exist in agents/ (they were eliminated). agents/ contains only
#     runtime subagents — Sprint 4 owns those assertions.
[ ! -f "agents/implementation.md" ] && [ ! -f "agents/validation.md" ] \
  && pass "spec-phase / pre-rename agent files removed in v1.1" \
  || err "old agent file (implementation.md or validation.md) still present"

# 13. tech-spec-task-split Part 3: /yoke:acceptance-contract migrated to
#     the new spec + per-task layout.
ac_skill="skills/acceptance-contract/SKILL.md"
if grep -q "wm_tech_spec_path" "$ac_skill"; then
  err "$ac_skill still references wm_tech_spec_path (Part 3 should have migrated it)"
else
  pass "$ac_skill migrated off wm_tech_spec_path"
fi
for marker in "wm_spec_path" "wm_list_task_paths" "one scenario per task file" "Task: <task-id>"; do
  if grep -qF "$marker" "$ac_skill"; then
    pass "$ac_skill references '$marker'"
  else
    err "$ac_skill missing '$marker'"
  fi
done

ac_tpl="templates/acceptance-contract.md"
if grep -qF "Task: <slug>-s01-t01" "$ac_tpl"; then
  pass "$ac_tpl scenario template carries the 'Task:' anchor line"
else
  err "$ac_tpl scenario template missing 'Task:' anchor line"
fi
if grep -qE "Exactly one scenario per task file|one BDD scenario per task" "$ac_tpl"; then
  pass "$ac_tpl pins the 1:1 scenario-per-task contract"
else
  err "$ac_tpl missing 1:1 scenario-per-task contract"
fi

# 14. tech-spec-task-split Part 3: migration helper in place, executable,
#     non-destructive, and exposes the 3-stage pipeline.
mig="lib/working-memory/migrate-tech-specs.sh"
if [ -x "$mig" ]; then
  pass "$mig present and executable"
else
  err "$mig missing or not executable"
fi
for marker in "Stage 1" "Stage 2" "Stage 3" "scaffold-tasks.sh" "non-destructive" "--scaffold"; do
  if grep -qF -- "$marker" "$mig"; then
    pass "$mig references '$marker'"
  else
    err "$mig missing '$marker'"
  fi
done

# Behavioral check: --scaffold without a prior new spec exits 4.
# `set -e` is active at this point in the file, so capture exit
# explicitly via `|| mig_exit=$?` to avoid aborting on the expected
# non-zero exit.
mig_tmp="$(mktemp -d)"
mig_slug="2026-04-25-mig-smoke"
mkdir -p "$mig_tmp/.yoke/tech-specs"
echo "# legacy" > "$mig_tmp/.yoke/tech-specs/${mig_slug}.md"
mig_exit=0
( cd "$mig_tmp" && bash "$PLUGIN_ROOT/$mig" --scaffold ".yoke/tech-specs/${mig_slug}.md" >/dev/null 2>&1 ) || mig_exit=$?
if [ "$mig_exit" -eq 4 ]; then
  pass "$mig --scaffold before Stage 1 exits 4 (precondition guard)"
else
  err "$mig --scaffold did not exit 4 (got $mig_exit)"
fi
rm -rf "$mig_tmp"

# 15. tech-spec-task-split Part 3: hooks/verify-acceptance.sh tolerates
#     the new BDD-per-task shape (Task: <id> line is opaque metadata).
contract_tmp="$(mktemp -d)"
contract="$contract_tmp/acceptance-contract.md"
cat > "$contract" <<'CONTRACT'
# Acceptance Contract — smoke

> Status: ratified

## Use cases (BDD scenarios)

### Scenario 1 — first
Task: 2026-04-25-foo-s01-t01
Given a request
When the user runs it
Then the result is 0
Fixture: none
Sensors: [linter]

### Scenario 2 — second
Task: 2026-04-25-foo-s01-t02
Given a request
When the user runs it
Then the result is 0
Fixture: none
Sensors: [linter]

## Sensors

### Computational
- linter: `true`

CONTRACT
out=$(bash hooks/verify-acceptance.sh "$contract" 2>&1) || true
echo "$out" | grep -q "results:" \
  && pass "verify-acceptance.sh parses BDD-per-task contract (Task: line opaque)" \
  || err "verify-acceptance.sh failed to parse BDD-per-task contract: $out"
echo "$out" | grep -q "linter" \
  && pass "verify-acceptance.sh ran the declared sensor against new shape" \
  || err "verify-acceptance.sh did not run linter sensor: $out"
rm -rf "$contract_tmp"

echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
