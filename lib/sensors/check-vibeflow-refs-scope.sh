#!/bin/bash
# check-vibeflow-refs-scope.sh — enforce that any remaining legacy-
# doctrine-directory reference in the repo lives only in an explicitly
# allowed location per the PRD anti-scope and sprint contract c3.
#
# Allowed locations (per c3):
#   .yoke/{prds,tasks,specs,sensors,acceptance-contracts,contracts,runtime}/
#   CLAUDE.md
#   docs/lineage.md
#   tests/
#
# Exits 0 if no out-of-scope references; non-zero with the file list
# otherwise.

set -euo pipefail

needle=".vi""beflow/"

out_of_scope=$(find . -path ./node_modules -prune -o -name '*.md' -print 2>/dev/null \
  | xargs grep -lF "$needle" 2>/dev/null \
  | grep -vE '^(\./)?(\.yoke/(prds|tasks|specs|sensors|acceptance-contracts|contracts|runtime)/|CLAUDE\.md|docs/lineage\.md|tests/)' \
  || true)

if [ -n "$out_of_scope" ]; then
  echo "$out_of_scope" >&2
  echo "scope check: $(echo "$out_of_scope" | wc -l) file(s) out-of-scope (per sprint contract c3 allowed list)" >&2
  exit 1
fi
exit 0
