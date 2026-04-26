#!/usr/bin/env bash
# tests/bootstrap.test.sh
#
# /yoke:bootstrap host-project scaffolding:
#   (a) simulating bootstrap's file effects creates .yoke/config.yaml and
#       .yoke/.gitignore (content exactly .current\nruntime/)
#   (b) the host repo's working tree shows the new .yoke/ files but no
#       auto-commit was made by the simulation (mirroring the SKILL's
#       declared no-host-pollution invariant)
#   (c) skills/bootstrap/SKILL.md declares the canonical-memory
#       registration step (registry.sh add) and the no-pollute-host-repo
#       invariant
#
# Skills are markdown — they are not directly executable. The dynamic
# part of this test exercises the file effects the SKILL prescribes
# (mkdir + .yoke/config.yaml + .yoke/.gitignore) using only host-repo
# operations; canonical-memory registration is exercised in
# tests/canonical-memory-read.test.sh.

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

SKILL="skills/bootstrap/SKILL.md"
[ -f "$SKILL" ] || { err "skills/bootstrap/SKILL.md missing"; harness::summary; }

# ---------------------------------------------------------------------
# (c) SKILL declares the registration step + host-repo invariant
# ---------------------------------------------------------------------
if grep -q 'registry\.sh' "$SKILL" && grep -qiE 'register|registering' "$SKILL"; then
  pass "(c) bootstrap SKILL declares registry.sh registration step"
else
  err "(c) bootstrap SKILL does not declare registration step"
fi

if grep -qiE 'touches only|do not write outside|never overwritten if present' "$SKILL"; then
  pass "(c) bootstrap SKILL declares no-pollute-host-repo invariant"
else
  err "(c) bootstrap SKILL missing no-pollute-host-repo invariant"
fi

# ---------------------------------------------------------------------
# (a, b) Simulate the SKILL's file effects in a clean host repo
# ---------------------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

(
  cd "$TMP"
  git init -q
  git config --local user.email "test@example.com"
  git config --local user.name "test"

  echo "# host project" > README.md
  git add README.md
  git -c commit.gpgsign=false commit -q -m "initial"

  # Mirror SKILL Step 5: write .yoke/config.yaml and .yoke/.gitignore.
  mkdir -p .yoke
  cat > .yoke/config.yaml <<'YAML'
yoke_version: "test"
canonical_memory:
  url: ""
  name: ""
created_at: "2026-04-25"
YAML
  printf '.current\nruntime/\n' > .yoke/.gitignore
)

# (a) Files exist
if [ -f "$TMP/.yoke/config.yaml" ]; then
  pass "(a) .yoke/config.yaml created"
else
  err "(a) .yoke/config.yaml missing"
fi

if [ -f "$TMP/.yoke/.gitignore" ]; then
  pass "(a) .yoke/.gitignore created"
else
  err "(a) .yoke/.gitignore missing"
fi

gi=$(cat "$TMP/.yoke/.gitignore")
expected=$'.current\nruntime/'
if [ "$gi" = "$expected" ]; then
  pass "(a) .yoke/.gitignore content is exactly .current\\nruntime/"
else
  err "(a) .yoke/.gitignore content unexpected:"
  printf '%s\n' "$gi" | sed 's/^/    /' >&2
fi

# (b) host repo's working tree shows the new files but no auto-commit
status=$(git -C "$TMP" status --porcelain 2>/dev/null)
if echo "$status" | grep -q '^?? \.yoke/'; then
  pass "(b) .yoke/ is untracked in host repo (no auto-commit)"
else
  err "(b) .yoke/ not seen as untracked: $status"
fi

commit_count=$(git -C "$TMP" rev-list --count HEAD 2>/dev/null || echo 0)
if [ "$commit_count" = "1" ]; then
  pass "(b) host repo has exactly 1 commit (no auto-commit by simulated bootstrap)"
else
  err "(b) host repo has $commit_count commits (expected 1)"
fi

harness::summary
