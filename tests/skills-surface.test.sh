#!/usr/bin/env bash
# tests/skills-surface.test.sh
#
# Structural contract of every SKILL.md and the binding invariants of
# the spec-phase skills + /yoke:ask:
#
#   (1) per-skill frontmatter — delimiters, name, description, allowed-tools
#   (2) spec-phase skills (discover, tech-spec, acceptance-contract):
#         - allowed-tools excludes Task
#         - inline persona section
#         - binding human-trigger prompt (Trigger 1/2/3 respectively)
#   (3) /yoke:ask:
#         - allowed-tools excludes Task and Write (pure read)
#         - declares the no-clone invariant
#         - declares no-fabrication
#         - references resolve-memory.sh
#         - caps entity reads at 15

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------

# Returns 0 if SKILL.md's first frontmatter block contains a key.
fm_has_field() {
  local f=$1 field=$2
  awk -v field="^${field}:" '
    BEGIN { c = 0; found = 0 }
    /^---$/ { c++; if (c >= 2) exit }
    c == 1 && $0 ~ field { found = 1 }
    END { exit (found ? 0 : 1) }
  ' "$f"
}

# Print the value (rest of the line) of a single-line frontmatter field.
fm_field_value() {
  local f=$1 field=$2
  awk -v field="^${field}:" '
    BEGIN { c = 0 }
    /^---$/ { c++; if (c >= 2) exit }
    c == 1 && $0 ~ field {
      sub(field, "")
      sub(/^ */, "")
      print
      exit
    }
  ' "$f"
}

# ---------------------------------------------------------------------
# (1) Per-skill frontmatter
# ---------------------------------------------------------------------
for f in skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  rel="${f#skills/}"; rel="${rel%/SKILL.md}"

  delim_count=$(grep -c '^---$' "$f" || true)
  if [ "$delim_count" -ge 2 ]; then
    pass "$rel: frontmatter delimiters present"
  else
    err "$rel: frontmatter missing --- delimiters (count=$delim_count)"
    continue
  fi

  fm_has_field "$f" "name" \
    && pass "$rel: name field present" \
    || err "$rel: name field missing"

  fm_has_field "$f" "description" \
    && pass "$rel: description field present" \
    || err "$rel: description field missing"

  fm_has_field "$f" "allowed-tools" \
    && pass "$rel: allowed-tools field present" \
    || err "$rel: allowed-tools field missing"
done

# ---------------------------------------------------------------------
# (2) Spec-phase skills
# ---------------------------------------------------------------------

# allowed-tools must exclude Task — skills deliberate, subagents adapt.
for skill in discover tech-spec acceptance-contract; do
  f="skills/${skill}/SKILL.md"
  if [ ! -f "$f" ]; then
    err "$skill: SKILL.md missing"
    continue
  fi

  tools=$(fm_field_value "$f" "allowed-tools")
  if echo "$tools" | grep -qw "Task"; then
    err "$skill: allowed-tools includes Task (must be inline, no subagent spawn): $tools"
  else
    pass "$skill: allowed-tools excludes Task"
  fi

  if grep -qE 'Generator persona|Validator persona|Your role .*persona' "$f"; then
    pass "$skill: embeds inline persona section"
  else
    err "$skill: missing inline persona section"
  fi
done

# Binding human-trigger prompts.
declare -A trigger_map=(
  [discover]="Trigger 1"
  [tech-spec]="Trigger 2"
  [acceptance-contract]="Trigger 3"
)
for skill in "${!trigger_map[@]}"; do
  trigger="${trigger_map[$skill]}"
  f="skills/${skill}/SKILL.md"
  if grep -qF -- "$trigger" "$f"; then
    pass "$skill: declares ${trigger} binding prompt"
  else
    err "$skill: missing ${trigger} binding prompt"
  fi
done

# ---------------------------------------------------------------------
# (3) /yoke:ask
# ---------------------------------------------------------------------
ask="skills/ask/SKILL.md"
if [ ! -f "$ask" ]; then
  err "ask: SKILL.md missing"
else
  ask_tools=$(fm_field_value "$ask" "allowed-tools")

  if echo "$ask_tools" | grep -qw "Task"; then
    err "ask: allowed-tools includes Task (must be pure read): $ask_tools"
  else
    pass "ask: allowed-tools excludes Task"
  fi

  if echo "$ask_tools" | grep -qw "Write"; then
    err "ask: allowed-tools includes Write (must be pure read): $ask_tools"
  else
    pass "ask: allowed-tools excludes Write"
  fi

  grep -qiE 'never .*(clone|pull|fetch)' "$ask" \
    && pass "ask: declares no-clone invariant" \
    || err "ask: missing no-clone declaration"

  grep -qiE 'never fabricate|do not fabricate|never invent' "$ask" \
    && pass "ask: declares no-fabrication rule" \
    || err "ask: missing no-fabrication declaration"

  grep -q 'resolve-memory.sh' "$ask" \
    && pass "ask: references resolve-memory.sh" \
    || err "ask: missing resolve-memory.sh reference"

  grep -qE '15 entit|cap.*15|≤[[:space:]]*15|limit:?[[:space:]]*15' "$ask" \
    && pass "ask: caps entity reads at 15" \
    || err "ask: missing 15-entity cap"
fi

harness::summary
