#!/usr/bin/env bash
# tests/working-memory.test.sh
#
# Working-memory layout invariants:
#   (a) every file written under .yoke/ lands in an allowed location
#       (config.yaml, .gitignore, prds/<slug>.md,
#        tech-specs/<slug>.md, acceptance-contracts/<slug>.md,
#        contracts/<slug>.md, runtime/* — including runtime/.current)
#   (b) no flat .yoke/<file>.md exists for
#       prd|tech-spec|acceptance-contract|contracts|progress
#   (c) static grep over skills/, lib/, hooks/ finds no flat-path strings
#       outside paths.sh
#   (d) .gitignore content is exactly runtime/
#   (e) .yoke/runtime/.current size equals the slug byte length (no trailing newline)
#
# The dynamic flow exercises lib/working-memory/paths.sh directly in a
# tmpdir; skills are markdown — exercising prose belongs to spec phase,
# not tests.

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (c) Static check — no hardcoded flat-path strings outside paths.sh
# ---------------------------------------------------------------------
flat_hits=$(grep -RIn -E '\.yoke/(prd|tech-spec|acceptance-contract|contracts|progress)\.md' \
              skills/ lib/ hooks/ \
              2>/dev/null \
              | grep -v 'paths\.sh' \
              | grep -viE 'DO NOT|do not write|do not modify|flat path|no flat file|like `\.yoke/' \
              || true)

if [ -z "$flat_hits" ]; then
  pass "(c) no hardcoded flat-path strings outside paths.sh"
else
  err "(c) flat-path strings found:"
  printf '%s\n' "$flat_hits" | sed 's/^/    /' >&2
fi

# ---------------------------------------------------------------------
# (a, b, d, e) Dynamic — simulate end-to-end flow in a tmpdir
# ---------------------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
SLUG="2026-04-25-wm-smoke"

(
  cd "$TMP"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/working-memory/paths.sh"

  mkdir -p .yoke
  cat > .yoke/config.yaml <<'YAML'
yoke_version: "test"
canonical_memory:
  url: ""
YAML
  printf 'runtime/\n' > .yoke/.gitignore

  wm_wipe_runtime
  mkdir -p "$(dirname "$(wm_prd_path "$SLUG")")"
  printf '# PRD\n> Status: approved\n' > "$(wm_prd_path "$SLUG")"
  wm_set_active "$SLUG"

  mkdir -p "$(dirname "$(wm_spec_path)")"
  printf '# Tech Spec\n> Status: approved\n' > "$(wm_spec_path)"

  mkdir -p "$(dirname "$(wm_acceptance_contract_path)")"
  printf '# Acceptance Contract\n> Status: ratified\n' > "$(wm_acceptance_contract_path)"

  mkdir -p "$(dirname "$(wm_contracts_path)")"
  printf '# Sprint contracts\n' > "$(wm_contracts_path)"

  mkdir -p "$(wm_runtime_dir)" "$(wm_snapshots_dir)"
  printf '# Progress\n' > "$(wm_progress_path)"
  echo 1 > "$(wm_cycle_counter_path)"
  printf 'results:\n  - sensor: smoke\n    status: pass\n' > "$(wm_snapshots_dir)/cycle-1.yaml"
)

# (a) Allowed-location scan
unexpected=()
while IFS= read -r f; do
  rel=${f#"$TMP"/}
  case "$rel" in
    .yoke/config.yaml) ;;
    .yoke/.gitignore) ;;
    .yoke/prds/"$SLUG".md) ;;
    .yoke/specs/"$SLUG".md) ;;
    .yoke/tasks/*) ;;
    .yoke/acceptance-contracts/"$SLUG".md) ;;
    .yoke/contracts/"$SLUG".md) ;;
    .yoke/runtime/*) ;;
    *) unexpected+=("$rel") ;;
  esac
done < <(find "$TMP/.yoke" -type f 2>/dev/null)

if [ "${#unexpected[@]}" -eq 0 ]; then
  pass "(a) every file under .yoke/ is in an allowed location"
else
  err "(a) unexpected file locations:"
  printf '    %s\n' "${unexpected[@]}" >&2
fi

# (b) No flat .yoke/<file>.md for the canonical artifacts
forbidden=(
  "$TMP/.yoke/prd.md"
  "$TMP/.yoke/tech-spec.md"
  "$TMP/.yoke/acceptance-contract.md"
  "$TMP/.yoke/contracts.md"
  "$TMP/.yoke/progress.md"
)
flat_present=()
for f in "${forbidden[@]}"; do
  [ -e "$f" ] && flat_present+=("${f#"$TMP"/}")
done

if [ "${#flat_present[@]}" -eq 0 ]; then
  pass "(b) no flat-path .yoke/<file>.md files were created"
else
  err "(b) flat-path files exist:"
  printf '    %s\n' "${flat_present[@]}" >&2
fi

# (d) .gitignore content exact
gi=$(cat "$TMP/.yoke/.gitignore")
expected_gi='runtime/'
if [ "$gi" = "$expected_gi" ]; then
  pass "(d) .gitignore content is exactly runtime/"
else
  err "(d) .gitignore content unexpected:"
  printf '%s\n' "$gi" | sed 's/^/    /' >&2
fi

# (e) runtime/.current size = slug byte length (no trailing newline)
on_disk=$(wc -c < "$TMP/.yoke/runtime/.current" | tr -d ' ')
expected_size=$(printf %s "$SLUG" | wc -c | tr -d ' ')
if [ "$on_disk" = "$expected_size" ]; then
  pass "(e) runtime/.current is exactly the slug ($on_disk bytes; no trailing newline)"
else
  err "(e) runtime/.current size mismatch (on_disk=$on_disk expected=$expected_size)"
fi

# ---------------------------------------------------------------------
# (f, g, h, i) cleanup.sh helpers — gated runtime wipe + gitignore heal
# ---------------------------------------------------------------------

# (f) wm_runtime_cleanup deletes contents on MERGE-READY + canonize-success
# (g) wm_runtime_cleanup is a no-op on paused exits / canonize failure
TMP_F=$(mktemp -d)
trap 'rm -rf "$TMP" "$TMP_F" "$TMP_GH" "$TMP_TR"' EXIT

(
  cd "$TMP_F"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/working-memory/paths.sh"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/working-memory/cleanup.sh"

  mkdir -p "$(wm_runtime_dir)/.snapshots"
  printf '# Progress\n' > "$(wm_progress_path)"
  printf '1\n' > "$(wm_cycle_counter_path)"
  printf 'cycle: 1\n' > "$(wm_snapshots_dir)/cycle-1.yaml"

  # MERGE-READY + canonize success → wipe
  wm_runtime_cleanup "merge-ready" "0" >/dev/null

  remaining=$(find "$(wm_runtime_dir)" -mindepth 1 -print 2>/dev/null | wc -l | tr -d ' ')
  echo "$remaining" > /tmp/.yoke-cleanup-remaining-merge-ready

  # Stage runtime again for the paused-exit assertion
  mkdir -p "$(wm_snapshots_dir)"
  printf '# Progress\n' > "$(wm_progress_path)"
  printf 'cycle: 1\n' > "$(wm_snapshots_dir)/cycle-1.yaml"

  # Paused exit → no-op
  wm_runtime_cleanup "hard-bound" "0" >/dev/null
  remaining_paused=$(find "$(wm_runtime_dir)" -mindepth 1 -print 2>/dev/null | wc -l | tr -d ' ')
  echo "$remaining_paused" > /tmp/.yoke-cleanup-remaining-paused

  # MERGE-READY but canonize failed → no-op
  wm_runtime_cleanup "merge-ready" "7" >/dev/null
  remaining_canonize_fail=$(find "$(wm_runtime_dir)" -mindepth 1 -print 2>/dev/null | wc -l | tr -d ' ')
  echo "$remaining_canonize_fail" > /tmp/.yoke-cleanup-remaining-canonize-fail
)

f_remaining=$(cat /tmp/.yoke-cleanup-remaining-merge-ready)
g_paused=$(cat /tmp/.yoke-cleanup-remaining-paused)
g_canonize_fail=$(cat /tmp/.yoke-cleanup-remaining-canonize-fail)
rm -f /tmp/.yoke-cleanup-remaining-merge-ready /tmp/.yoke-cleanup-remaining-paused /tmp/.yoke-cleanup-remaining-canonize-fail

if [ "$f_remaining" = "0" ]; then
  pass "(f) wm_runtime_cleanup wipes runtime contents on merge-ready + canonize-success"
else
  err "(f) wm_runtime_cleanup left $f_remaining file(s) after merge-ready + canonize-success"
fi

if [ "$g_paused" -gt 0 ] && [ "$g_canonize_fail" -gt 0 ]; then
  pass "(g) wm_runtime_cleanup preserves runtime on paused exits and canonize failure"
else
  err "(g) wm_runtime_cleanup wiped runtime when it should have preserved it (paused=$g_paused canonize_fail=$g_canonize_fail)"
fi

# (h) wm_gitignore_self_heal repairs missing/incomplete .yoke/.gitignore
TMP_GH=$(mktemp -d)
(
  cd "$TMP_GH"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/working-memory/paths.sh"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/working-memory/cleanup.sh"

  # Case 1: missing → repaired
  rm -rf .yoke
  output_missing=$(wm_gitignore_self_heal)
  echo "$output_missing" > /tmp/.yoke-heal-output-missing
  cp .yoke/.gitignore /tmp/.yoke-heal-content-missing

  # Case 2: incomplete (empty file) → repaired
  : > .yoke/.gitignore
  output_incomplete=$(wm_gitignore_self_heal)
  echo "$output_incomplete" > /tmp/.yoke-heal-output-incomplete
  cp .yoke/.gitignore /tmp/.yoke-heal-content-incomplete

  # Case 3: already correct → silent
  output_correct=$(wm_gitignore_self_heal)
  echo "$output_correct" > /tmp/.yoke-heal-output-correct
)

heal_missing=$(cat /tmp/.yoke-heal-output-missing)
heal_incomplete=$(cat /tmp/.yoke-heal-output-incomplete)
heal_correct=$(cat /tmp/.yoke-heal-output-correct)
heal_content_missing=$(cat /tmp/.yoke-heal-content-missing)
heal_content_incomplete=$(cat /tmp/.yoke-heal-content-incomplete)
rm -f /tmp/.yoke-heal-output-missing /tmp/.yoke-heal-output-incomplete /tmp/.yoke-heal-output-correct \
      /tmp/.yoke-heal-content-missing /tmp/.yoke-heal-content-incomplete

expected_gi_full='runtime/'
if [ -n "$heal_missing" ] \
   && [ -n "$heal_incomplete" ] \
   && [ -z "$heal_correct" ] \
   && [ "$heal_content_missing" = "$expected_gi_full" ] \
   && [ "$heal_content_incomplete" = "$expected_gi_full" ]; then
  pass "(h) wm_gitignore_self_heal: silent on correct, one-line on repair, content canonical"
else
  err "(h) wm_gitignore_self_heal misbehaved (missing='$heal_missing' incomplete='$heal_incomplete' correct='$heal_correct')"
fi

# (i) wm_check_runtime_tracked emits a hint when runtime/ is tracked,
#     never modifies git state, and is silent when not tracked
TMP_TR=$(mktemp -d)
(
  cd "$TMP_TR"
  git init -q
  git config user.email "test@example.com"
  git config user.name  "Test"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/working-memory/paths.sh"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/working-memory/cleanup.sh"

  mkdir -p "$(wm_runtime_dir)"
  printf '# leaked\n' > "$(wm_runtime_dir)/progress.md"
  git add -f "$(wm_runtime_dir)/progress.md"
  git commit -q -m "leak"

  before_status=$(git status --porcelain)
  output_tracked=$(wm_check_runtime_tracked)
  after_status=$(git status --porcelain)
  echo "$output_tracked" > /tmp/.yoke-tr-output-tracked
  echo "$before_status" > /tmp/.yoke-tr-status-before
  echo "$after_status"  > /tmp/.yoke-tr-status-after

  # Untrack and re-check: silent
  git rm -q --cached "$(wm_runtime_dir)/progress.md"
  git commit -q -m "untrack"
  rm -f "$(wm_runtime_dir)/progress.md"
  output_untracked=$(wm_check_runtime_tracked)
  echo "$output_untracked" > /tmp/.yoke-tr-output-untracked
)

tr_tracked=$(cat /tmp/.yoke-tr-output-tracked)
tr_before=$(cat /tmp/.yoke-tr-status-before)
tr_after=$(cat /tmp/.yoke-tr-status-after)
tr_untracked=$(cat /tmp/.yoke-tr-output-untracked)
rm -f /tmp/.yoke-tr-output-tracked /tmp/.yoke-tr-status-before /tmp/.yoke-tr-status-after /tmp/.yoke-tr-output-untracked

if echo "$tr_tracked" | grep -q "git rm -r --cached .yoke/runtime/" \
   && [ "$tr_before" = "$tr_after" ] \
   && [ -z "$tr_untracked" ]; then
  pass "(i) wm_check_runtime_tracked emits hint when tracked, silent when not, never mutates git"
else
  err "(i) wm_check_runtime_tracked misbehaved (tracked='$tr_tracked' status_changed='$([ "$tr_before" != "$tr_after" ] && echo yes || echo no)' untracked='$tr_untracked')"
fi

harness::summary
