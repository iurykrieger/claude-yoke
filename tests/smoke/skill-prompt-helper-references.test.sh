#!/usr/bin/env bash
# tests/smoke/skill-prompt-helper-references.test.sh
#
# Sensor: skill-prompt-helper-references (computational, cheap).
#
# Pins the regression class documented in
# https://github.com/iurykrieger/claude-yoke/issues/31:
# skill prompts (`skills/*/SKILL.md`) drifted away from the running
# code. Concretely, `/yoke:ask` and `/yoke:status` referenced
# `lib/canonical-memory/resolve-memory.sh` and `yoke_resolve_memory`
# — both retired in the v2.0.0 facade extraction (only
# `resolve-provider.sh` and `yoke_resolve_provider` survived).
# Invoking those skills crashed the host with `exit 127, no such
# file or directory`. v1.x `memories.json` references in the same
# region had the same shape.
#
# This sensor is the structural pin against re-introduction of that
# class of drift in any current or future skill prompt.
#
# Coverage:
#   (A) Every `lib/<helper>.sh` path mentioned in any
#       `skills/**/SKILL.md` resolves to a file that exists on disk.
#       The `bootstrap/` skill is exempt because it documents the
#       v1.x migration path and references retired files (e.g.
#       `memories.json`) by intent.
#   (B) Every `agents/<file>.md` path mentioned in any
#       `skills/**/SKILL.md` resolves to a file that exists. Catches
#       reintroductions of retired v2.x agents (the binary-loop
#       Generator/Validator pair).
#   (C) The retired helper symbols `resolve-memory.sh` and
#       `yoke_resolve_memory` appear in zero non-bootstrap skill
#       prompts (bootstrap is exempt as the migration tool).
#   (D) The retired v2.x agent files are not referenced by any
#       skill prompt: `agents/generator.md`, `agents/validator.md`,
#       `agents/orchestrator.md` (the canonize-only `orchestrator.md`
#       was kept under that exact filename in v3.0, so this assertion
#       compares against existence rather than the literal string).
#       The check actually asserts no `agents/generator.md` or
#       `agents/validator.md` references exist anywhere under
#       `skills/`, since those two filenames were deleted in v3.0.
#   (E) The legacy `/yoke:ask` skill directory was deleted; any
#       cross-reference to that path in skill prompts must be
#       phrased as a historical note (i.e., the literal string
#       `/yoke:ask` may appear only in lines that also contain
#       `retired`, `legacy`, `v1.x`, `historical`, or appear inside
#       the bootstrap skill's migration-runbook scope).
#
# References:
# - Issue: #31
# - CLAUDE.md :: Migration history (v2.0.0 entry).

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

# Watchdog (concepts/yoke-conventions): never let a hung subshell block CI.
(sleep 600 && kill -TERM $$ &) >/dev/null 2>&1

cd "$PLUGIN_ROOT"

# Skills that document the v1.x → v2.0.0 migration path are exempt
# from the historical-symbol bans below. Today only bootstrap meets
# that criterion (its body must reference legacy paths to perform the
# migration).
is_bootstrap_skill() {
  case "$1" in
    skills/bootstrap/SKILL.md) return 0 ;;
  esac
  return 1
}

# A line counts as a historical note when it carries one of the
# qualifier tokens below — references inside such lines describe what
# was retired and are not active dispatch targets.
HISTORICAL_QUALIFIER_RE='(retired|legacy|v1\.x|v2\.x|historical|historically|deprecated|formerly|migrated)'

is_historical_line() {
  printf '%s' "$1" | grep -qiE "$HISTORICAL_QUALIFIER_RE"
}

# ----------------------------------------------------------------------
# (A) Every active lib/<helper>.sh referenced in skill prompts exists.
# Lines qualified as historical (retired / legacy / v1.x / v2.x /
# historical / historically / deprecated / formerly / migrated) are
# exempt — those references describe the past, not the current
# dispatch surface.
# ----------------------------------------------------------------------
a_missing=""
a_count=0
while IFS= read -r raw; do
  [ -z "$raw" ] && continue
  file="${raw%%:*}"
  payload_after_file="${raw#*:}"
  body="${payload_after_file#*:}"
  is_historical_line "$body" && continue
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    a_count=$((a_count + 1))
    if [ ! -f "$PLUGIN_ROOT/$path" ]; then
      a_missing+=$'\n'"  - $file references missing path (no historical qualifier): $path"
      a_missing+=$'\n'"      $body"
    fi
  done < <(printf '%s\n' "$body" | grep -oE 'lib/[A-Za-z0-9_./-]+\.sh' | sort -u)
done < <(grep -rnE 'lib/[A-Za-z0-9_./-]+\.sh' skills/ 2>/dev/null || true)

if [ -z "$a_missing" ]; then
  pass "(A) every active lib/<helper>.sh in skill prompts resolves on disk ($a_count reference(s) audited)"
else
  err "(A) lib/ helper references that do not resolve:$a_missing"
fi

# ----------------------------------------------------------------------
# (B) Every active agents/<file>.md referenced in skill prompts
# exists. Same historical-qualifier exemption as (A).
# ----------------------------------------------------------------------
b_missing=""
b_count=0
while IFS= read -r raw; do
  [ -z "$raw" ] && continue
  file="${raw%%:*}"
  payload_after_file="${raw#*:}"
  body="${payload_after_file#*:}"
  is_historical_line "$body" && continue
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    b_count=$((b_count + 1))
    if [ ! -f "$PLUGIN_ROOT/$path" ]; then
      b_missing+=$'\n'"  - $file references missing path (no historical qualifier): $path"
      b_missing+=$'\n'"      $body"
    fi
  done < <(printf '%s\n' "$body" | grep -oE 'agents/[A-Za-z0-9_./-]+\.md' | sort -u)
done < <(grep -rnE 'agents/[A-Za-z0-9_./-]+\.md' skills/ 2>/dev/null || true)

if [ -z "$b_missing" ]; then
  pass "(B) every active agents/<file>.md in skill prompts resolves on disk ($b_count reference(s) audited)"
else
  err "(B) agents/ references that do not resolve:$b_missing"
fi

# ----------------------------------------------------------------------
# (C) Retired helper symbols outside the bootstrap migration runbook.
# ----------------------------------------------------------------------
c_violations=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  is_bootstrap_skill "$f" && continue
  if grep -qE 'resolve-memory\.sh|yoke_resolve_memory' "$f"; then
    hits="$(grep -nE 'resolve-memory\.sh|yoke_resolve_memory' "$f" | head -3)"
    c_violations+=$'\n'"  - $f:"$'\n'"$hits"
  fi
done < <(find skills -name 'SKILL.md' -type f 2>/dev/null)

if [ -z "$c_violations" ]; then
  pass "(C) no retired resolve-memory.sh / yoke_resolve_memory references in non-bootstrap skill prompts"
else
  err "(C) retired helper symbols leaked into skill prompts:$c_violations"
fi

# ----------------------------------------------------------------------
# (D) Retired v2.x agent filenames must not appear under skills/ as
# active references. `agents/orchestrator.md` survives in
# canonize-only mode (kept under the same filename), so it is NOT in
# this banned list. Lines qualified as historical are exempt — they
# explicitly document the v2.x → v3.0 transition.
# ----------------------------------------------------------------------
d_violations=""
while IFS= read -r raw; do
  [ -z "$raw" ] && continue
  file="${raw%%:*}"
  payload_after_file="${raw#*:}"
  body="${payload_after_file#*:}"
  is_historical_line "$body" && continue
  d_violations+=$'\n'"  - $file:"$'\n'"      $body"
done < <(grep -rnE 'agents/(generator|validator)\.md' skills/ 2>/dev/null || true)

if [ -z "$d_violations" ]; then
  pass "(D) no active references to retired v2.x agent filenames (generator.md / validator.md) in skill prompts"
else
  err "(D) retired v2.x agent filenames referenced as active dispatch:$d_violations"
fi

# ----------------------------------------------------------------------
# (E) The legacy /yoke:ask skill is gone — every surviving reference
# must be a historical note.
# ----------------------------------------------------------------------
[ -d "$PLUGIN_ROOT/skills/ask" ] \
  && err "(E) skills/ask/ directory still exists — the legacy skill was supposed to be retired in v2.0.0" \
  || pass "(E) skills/ask/ directory deleted (the v1.x reader migrated to claude-bedrock)"

e_naked=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  file="${line%%:*}"
  is_bootstrap_skill "$file" && continue
  # The line that documents the retirement itself must mention one of
  # the historical-context tokens. Other mentions are drift.
  if printf '%s' "$line" | grep -qiE '\b(retired|legacy|v1\.x|historical|deprecated|migrated)\b'; then
    continue
  fi
  e_naked+=$'\n'"  - $line"
done < <(grep -rnE '/yoke:ask\b' skills/ 2>/dev/null || true)

if [ -z "$e_naked" ]; then
  pass "(E) every surviving /yoke:ask reference is qualified as historical/retired"
else
  err "(E) unqualified /yoke:ask references (not in a historical-note context):$e_naked"
fi

harness::summary
