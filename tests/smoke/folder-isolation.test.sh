#!/bin/bash
# tests/smoke/folder-isolation.test.sh
#
# v0.6.0 smoke test — verifies the per-category-folder layout for `.yoke/`
# working memory. Asserts:
#   (a) every file written under `.yoke/` lands in an allowed location
#       (config.yaml, .gitignore, .current, prds/<slug>.md,
#        tech-specs/<slug>.md, acceptance-contracts/<slug>.md,
#        contracts/<slug>.md, runtime/<file>);
#   (b) no flat file `.yoke/<file>.md` for any of
#       prd|tech-spec|acceptance-contract|contracts|progress is ever
#       created by the simulated flow;
#   (c) no skill or hook constructs `.yoke/<file>.md` paths via string
#       concatenation — every path goes through `lib/working-memory/paths.sh`.
#
# Note: the `query-traces/` category was retired in
# ask-source-agnostic-read Part 1 — the trace concept no longer exists.
#
# The skills themselves are prose-driven; this test simulates the flow by
# invoking the path helper directly and checking that no other location
# is touched. Static grep checks cover (c).
#
# Pre-Sprint-6: no ralph loop is invoked. External timeout not strictly
# required.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Folder-isolation smoke (v0.6.0) ---"

# ---------- Static check (c): no hardcoded flat-path strings -----------

echo
echo "[c] Hardcoded flat-path scan"

# Allowed exception: lib/working-memory/paths.sh is the single helper that
# *defines* layout strings — it must be excluded from the flat-path ban.
# Exclude documentation occurrences where the string is explicitly
# forbidden or used as a "no flat file like X" comparison.
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

# query-traces/ retired in ask-source-agnostic-read Part 1; ensure no
# live references survived in skills/ or lib/.
qt_hits=$(grep -RIn -E '\.yoke/query-traces?(/<slug>)?\.md' skills/ lib/ hooks/ 2>/dev/null \
           | grep -viE 'do not (read|write)|does not exist|retired|removed' \
           || true)
if [ -z "$qt_hits" ]; then
  pass "(c) no live query-trace references in skills/ lib/ hooks/"
else
  err "(c) live query-trace references found:"
  printf '%s\n' "$qt_hits" | sed 's/^/    /' >&2
fi

# ---------- Dynamic check (a)+(b): simulate a flow in a tmpdir --------

echo
echo "[a/b] Simulated end-to-end flow"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
SLUG="2026-05-01-folder-isolation-smoke"

(
  cd "$TMP"
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/lib/working-memory/paths.sh"

  # Bootstrap: config.yaml + .gitignore. Mirror skills/bootstrap/SKILL.md prose.
  mkdir -p .yoke
  cat > .yoke/config.yaml <<'YAML'
yoke_version: "0.6.0"
canonical_memory:
  url: ""
YAML
  printf '.current\nruntime/\n' > .yoke/.gitignore

  # Discover: wipe runtime, lazily mkdir prds/, write PRD, set .current.
  wm_wipe_runtime
  mkdir -p "$(dirname "$(wm_prd_path "$SLUG")")"
  cat > "$(wm_prd_path "$SLUG")" <<'MD'
# PRD: Folder isolation smoke
> Status: approved
> Approved by: smoke-test
> Approved at: 2026-05-01
MD
  wm_set_active "$SLUG"

  # Tech spec.
  mkdir -p "$(dirname "$(wm_tech_spec_path)")"
  cat > "$(wm_tech_spec_path)" <<'MD'
# Tech Spec: Folder isolation smoke
> Status: approved
MD

  # Acceptance contract.
  mkdir -p "$(dirname "$(wm_acceptance_contract_path)")"
  cat > "$(wm_acceptance_contract_path)" <<'MD'
# Acceptance Contract: Folder isolation smoke
> Status: ratified
MD

  # Implement: contracts (versioned) + runtime files.
  mkdir -p "$(dirname "$(wm_contracts_path)")"
  printf '# Sprint contracts\n' > "$(wm_contracts_path)"
  mkdir -p "$(wm_runtime_dir)" "$(wm_snapshots_dir)"
  printf '# Progress\n' > "$(wm_progress_path)"
  echo "1" > "$(wm_cycle_counter_path)"
  printf 'results:\n  - sensor: smoke\n    status: pass\n' > "$(wm_snapshots_dir)/cycle-1.yaml"

  # /yoke:ask is a pure read in v1.2 — no working-memory side effects.
)

# Now scan everything written under .yoke/ and validate locations.
echo
echo "[a] Allowed-location scan of $TMP/.yoke"

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
  pass "(a) every file is in an allowed location"
else
  err "(a) unexpected file locations:"
  printf '    %s\n' "${unexpected[@]}" >&2
fi

# Verify no flat file at the legacy locations
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
  pass "(b) no flat-path files were created"
else
  err "(b) flat-path files exist:"
  printf '    %s\n' "${flat_present[@]}" >&2
fi

# .current bytes-exact
on_disk=$(wc -c < "$TMP/.yoke/.current" | tr -d ' ')
expected=$(printf %s "$SLUG" | wc -c | tr -d ' ')
if [ "$on_disk" = "$expected" ]; then
  pass ".current is exactly the slug (no trailing newline)"
else
  err ".current size mismatch (on_disk=$on_disk expected=$expected)"
fi

# .gitignore content exactly two lines
gi=$(cat "$TMP/.yoke/.gitignore")
if [ "$gi" = $'.current\nruntime/' ]; then
  pass ".gitignore content is exactly .current\\nruntime/"
else
  err ".gitignore content unexpected:"
  printf '%s\n' "$gi" | sed 's/^/    /' >&2
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "Folder-isolation smoke: PASS"
  exit 0
else
  echo "Folder-isolation smoke: FAIL ($fail check(s) failed)"
  exit 1
fi
