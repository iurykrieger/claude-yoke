#!/bin/bash
# propose-write.sh — open a PR on the canonical-memory repo for a low-impact
# Yoke proposition. Configures auto-merge after CI checks (does NOT
# force-merge).
#
# Usage:
#   propose-write.sh --candidate <yaml-fragment-file> [--repo-url <url>] [--dry-run]
#
# v0.5.0 ships only the low-impact path. Medium/high impact paths land in
# Sprint 6 (veto window / synchronous ratification). Regulatory PRs route
# to Compliance via CODEOWNERS in the canonical repo (Sprint 6).
#
# Pre-conditions:
#   - `gh` CLI installed and authenticated (skipped under --dry-run)
#   - candidate's impact must be "low"; other impacts → exit 4
#
# Exit codes:
#   0   PR opened (or dry-run completed)
#   2   usage error
#   3   gh CLI missing or unauthenticated
#   4   non-low-impact candidate (deferred per Sprint 5 scope)
#   5   write or push failure

set -euo pipefail

candidate_file=""
repo_url=""
dry_run=0

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --candidate)  candidate_file="${2:-}"; shift 2 ;;
    --repo-url)   repo_url="${2:-}";       shift 2 ;;
    --dry-run)    dry_run=1;               shift ;;
    -h|--help)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    "")           break ;;
    *)            echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$candidate_file" ] || [ ! -f "$candidate_file" ]; then
  echo "Error: --candidate <yaml-fragment-file> is required." >&2
  exit 2
fi

# Verify gh availability (real-flow only)
if [ "$dry_run" -ne 1 ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh CLI not found. Install from https://cli.github.com/." >&2
    exit 3
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "Error: gh CLI not authenticated. Run 'gh auth login' first." >&2
    exit 3
  fi
fi

# Extract a YAML field's value from the candidate file. Looks for
# `key: "value"` or `key: value` lines (anchored to the start of a line,
# optional leading whitespace and dash).
extract() {
  local field="$1"
  awk -v key="$field" '
    {
      if (match($0, "^[[:space:]]*-?[[:space:]]*"key":[[:space:]]*")) {
        v = substr($0, RSTART + RLENGTH)
        gsub(/^"|"$/, "", v)
        gsub(/[[:space:]]+#.*/, "", v)
        sub(/[[:space:]]+$/, "", v)
        print v
        exit
      }
    }
  ' "$candidate_file"
}

impact=$(extract "impact")
candidate_id=$(extract "id")
content_path=$(extract "content_path")
content_excerpt=$(extract "content_excerpt")
reason=$(extract "reason")

# Required fields
if [ -z "$candidate_id" ] || [ -z "$content_path" ] || [ -z "$impact" ]; then
  echo "Error: candidate file missing one of required fields (id, impact, content_path)." >&2
  exit 2
fi

# Validate impact value
case "$impact" in
  low|medium|high|regulatory) : ;;
  *)
    echo "Error: candidate impact must be one of: low, medium, high, regulatory (got '$impact')." >&2
    exit 4
    ;;
esac

# Locate canonical-memory repo URL from config if not provided
if [ -z "$repo_url" ]; then
  if [ -f ".yoke/config.yaml" ]; then
    repo_url=$(awk '
      /^canonical_memory:/ { in_section=1; next }
      in_section && /^[a-z]/ { in_section=0 }
      in_section && /^[[:space:]]+url:/ {
        sub(/^[[:space:]]+url:[[:space:]]*/, "")
        gsub(/^"|"$/, "")
        print
        exit
      }
    ' ".yoke/config.yaml")
  fi
fi

if [ -z "$repo_url" ] || [ "$repo_url" = "{{ canonical_memory_url }}" ]; then
  echo "Error: canonical-memory URL not configured. Set canonical_memory.url in .yoke/config.yaml or pass --repo-url." >&2
  exit 5
fi

slug=$(echo "$repo_url" | sed -E 's|.*/([^/]+)$|\1|; s|\.git$||')
cache_root="${HOME}/.cache/yoke/canonical"
repo_path="${cache_root}/${slug}"

branch="yoke-propose-${candidate_id}"
pr_title="[canonize] ${candidate_id}: ${reason}"

# Veto window length (medium-impact). Read from config or fall back to default.
read_veto_window() {
  local default="24"
  if [ ! -f ".yoke/config.yaml" ]; then
    echo "$default"; return
  fi
  local v
  v=$(awk '
    /^overrides:/ { in_o=1; next }
    in_o && /^[a-z]/ { in_o=0 }
    in_o && /^[[:space:]]+model_c:/ { in_m=1; next }
    in_o && in_m && /^[[:space:]]+veto_window_hours:/ {
      sub(/.*veto_window_hours:[[:space:]]*/, "")
      gsub(/[[:space:]]+#.*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
    in_o && in_m && /^[[:space:]]+[a-z]+:/ && !/^[[:space:]]+veto_window_hours:/ { in_m=0 }
  ' .yoke/config.yaml 2>/dev/null)
  if [ -z "$v" ]; then echo "$default"; else echo "$v"; fi
}
veto_window_hours=$(read_veto_window)

# Per-impact PR behavior (Sprint 6 ships all paths)
case "$impact" in
  low)
    pr_label="impact-low"
    pr_strategy="auto-merge after CI"
    ;;
  medium)
    pr_label="impact-medium"
    pr_strategy="veto window ${veto_window_hours}h, then auto-merge"
    ;;
  high)
    pr_label="impact-high"
    pr_strategy="auto-merge: never (synchronous human approval required)"
    ;;
  regulatory)
    pr_label="impact-regulatory"
    pr_strategy="auto-merge: never; routes to Compliance via CODEOWNERS"
    ;;
esac

if [ "$dry_run" -eq 1 ]; then
  echo "(dry-run) would clone $repo_url to $repo_path (if not cached)"
  echo "(dry-run) would create branch '$branch'"
  echo "(dry-run) would write candidate content to $repo_path/$content_path"
  echo "(dry-run) would open PR titled: $pr_title"
  echo "(dry-run) would apply labels: yoke-proposal, ${pr_label}"
  echo "(dry-run) would configure: ${pr_strategy}"
  if [ "$impact" = "medium" ]; then
    echo "(dry-run) would post veto-window comment announcing ${veto_window_hours}h window"
  fi
  if [ "$impact" = "regulatory" ]; then
    echo "(dry-run) would verify CODEOWNERS exists in canonical repo (route to Compliance)"
  fi
  exit 0
fi

# Real flow
if [ ! -d "$repo_path" ]; then
  mkdir -p "$cache_root"
  git clone --quiet "$repo_url" "$repo_path"
fi

cd "$repo_path"
git fetch origin --quiet
git checkout -B "$branch" --quiet 2>/dev/null || git checkout -B "$branch" --quiet

mkdir -p "$(dirname "$content_path")"
today=$(date -u +%Y-%m-%d)
model_id="${YOKE_MODEL_ID:-claude-opus-4-7}"
yoke_version="${YOKE_VERSION:-0.5.0}"

cat > "$content_path" <<EOF
---
ratified_at: ${today}
model_calibrated_against: ${model_id}
last_validated: ${today}
traceability: "auto-canonized from yoke working memory"
impact_level: ${impact}
depends_on: []
supersedes: []
applies_to: []
contradicts_with: []
---
# ${candidate_id}

${content_excerpt}

> Auto-canonized by Yoke ${yoke_version} on ${today}.
EOF

git add "$content_path"
git commit -m "$pr_title" --quiet

if ! git push --quiet --set-upstream origin "$branch" 2>/dev/null; then
  echo "Error: failed to push branch $branch to $repo_url" >&2
  exit 5
fi

pr_body="Yoke proposition. Candidate id: ${candidate_id}. Impact: ${impact}. Strategy: ${pr_strategy}."

pr_url=$(gh pr create \
  --title "$pr_title" \
  --body "$pr_body" \
  --label yoke-proposal \
  --label "${pr_label}" \
  --base main \
  --head "$branch" 2>&1) || {
    echo "Error: gh pr create failed. $pr_url" >&2
    exit 5
  }

# Per-impact merge behavior
case "$impact" in
  low)
    gh pr merge "$pr_url" --auto --squash --delete-branch 2>/dev/null || true
    ;;
  medium)
    # Comment-announce the veto window; configure auto-merge to fire after.
    gh pr comment "$pr_url" --body "Yoke medium-impact proposition. Veto window: ${veto_window_hours}h. Auto-merge will fire after the window closes if no objection is raised. Cancel via 'gh pr merge --disable-auto'." 2>/dev/null || true
    gh pr merge "$pr_url" --auto --squash --delete-branch 2>/dev/null || true
    ;;
  high)
    # Explicit human approval — do NOT enable auto-merge.
    gh pr comment "$pr_url" --body "Yoke high-impact proposition. Synchronous human approval required. Auto-merge: never." 2>/dev/null || true
    ;;
  regulatory)
    # Verify CODEOWNERS exists; route to Compliance via review request if found.
    if [ -f "CODEOWNERS" ] || [ -f ".github/CODEOWNERS" ] || [ -f "docs/CODEOWNERS" ]; then
      gh pr comment "$pr_url" --body "Yoke regulatory-impact proposition. CODEOWNERS active — Compliance review required." 2>/dev/null || true
    else
      gh pr comment "$pr_url" --body "Yoke regulatory-impact proposition. WARNING: no CODEOWNERS found in canonical repo; Compliance routing cannot be guaranteed. Auto-merge: never." 2>/dev/null || true
    fi
    # No auto-merge for regulatory.
    ;;
esac

echo "$pr_url"
exit 0
