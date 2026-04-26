#!/usr/bin/env bash
# tests/working-memory.test.sh
#
# Working-memory layout invariants:
#   (a) every file written under .yoke/ lands in an allowed location
#       (config.yaml, .gitignore, .current, prds/<slug>.md,
#        tech-specs/<slug>.md, acceptance-contracts/<slug>.md,
#        contracts/<slug>.md, runtime/*)
#   (b) no flat .yoke/<file>.md exists for
#       prd|tech-spec|acceptance-contract|contracts|progress
#   (c) static grep over skills/, lib/, hooks/ finds no flat-path strings
#       outside paths.sh
#   (d) .gitignore content is exactly .current\nruntime/
#   (e) .current size equals the slug byte length (no trailing newline)
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
  printf '.current\nruntime/\n' > .yoke/.gitignore

  wm_wipe_runtime
  mkdir -p "$(dirname "$(wm_prd_path "$SLUG")")"
  printf '# PRD\n> Status: approved\n' > "$(wm_prd_path "$SLUG")"
  wm_set_active "$SLUG"

  mkdir -p "$(dirname "$(wm_tech_spec_path)")"
  printf '# Tech Spec\n> Status: approved\n' > "$(wm_tech_spec_path)"

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
    .yoke/.current) ;;
    .yoke/prds/"$SLUG".md) ;;
    .yoke/tech-specs/"$SLUG".md) ;;
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
expected_gi=$'.current\nruntime/'
if [ "$gi" = "$expected_gi" ]; then
  pass "(d) .gitignore content is exactly .current\\nruntime/"
else
  err "(d) .gitignore content unexpected:"
  printf '%s\n' "$gi" | sed 's/^/    /' >&2
fi

# (e) .current size = slug byte length (no trailing newline)
on_disk=$(wc -c < "$TMP/.yoke/.current" | tr -d ' ')
expected_size=$(printf %s "$SLUG" | wc -c | tr -d ' ')
if [ "$on_disk" = "$expected_size" ]; then
  pass "(e) .current is exactly the slug ($on_disk bytes; no trailing newline)"
else
  err "(e) .current size mismatch (on_disk=$on_disk expected=$expected_size)"
fi

harness::summary
