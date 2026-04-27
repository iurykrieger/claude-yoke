#!/usr/bin/env bash
# migration-helpers.sh — slug derivation for one-shot legacy doctrine
# migration. Produces wm_validate_slug-compatible slugs from a source path
# by joining the file's first-commit date to its filename stem, with a
# documented truncation rule for stems that overflow the 50-char post-date
# budget.
#
# Source PRD: .yoke/prds/2026-04-27-yoke-doctrine-canonization.md
# (Sprint 3 / Scenario 9 deliverable).
#
# Truncation rule:
#   stems <= 50 chars          → "<YYYY-MM-DD>-<stem>"
#   stems  > 50 chars          → "<YYYY-MM-DD>-<truncated>-<hash>"
#                                where truncated = stem[:47] and hash =
#                                first 2 hex chars of sha1(stem). On
#                                collision retry with 4-char hash; hard-
#                                fail beyond that.

set -euo pipefail

# wm_first_commit_date <path>
# Echoes the first-commit ISO date for <path> in the current repo.
# Empty on miss.
wm_first_commit_date() {
  local path="${1:?wm_first_commit_date requires <path>}"
  git log --diff-filter=A --follow --format=%cs --reverse -- "$path" 2>/dev/null | head -1
}

# wm_migrate_slug <stem> [<date>] [<retry-len>]
# Returns a wm_validate_slug-compatible slug.
wm_migrate_slug() {
  local stem="${1:?wm_migrate_slug requires <stem>}"
  local date="${2:-2026-04-27}"
  local retry_len="${3:-2}"

  local stem_len=${#stem}
  if [ "$stem_len" -le 50 ]; then
    printf '%s-%s' "$date" "$stem"
    return 0
  fi

  local truncated="${stem:0:$((50 - retry_len - 1))}"
  local hash
  hash="$(printf '%s' "$stem" | shasum | head -c "$retry_len")"
  printf '%s-%s-%s' "$date" "$truncated" "$hash"
}

# Allow direct invocation for ad-hoc testing.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    first-commit-date)  wm_first_commit_date "$2" ;;
    migrate-slug)       wm_migrate_slug "$2" "${3:-}" "${4:-2}" ;;
    *)
      echo "usage: $0 first-commit-date <path>" >&2
      echo "       $0 migrate-slug <stem> [<date>] [<retry-len>]" >&2
      exit 2
      ;;
  esac
fi
