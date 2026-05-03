#!/usr/bin/env bash
# shellcheck shell=bash
#
# legacy-detect.test.sh — Sprint 04 / Task t04 happy-path unit test
# (US-007 DoD bullet 2; AC-007-2).
#
# Asserts that `lib/generate-sprints/legacy-detect.sh ::
# legacy_detect` correctly classifies the four shapes:
#   1. New-flow task (no legacy AC, no pre-existing sprint files) → 0.
#   2. Legacy AC archive present → 1 + literal stderr.
#   3. Pre-existing sprint file lacking new-flow traceability marker
#      → 1 + literal stderr.
#   4. Pre-existing sprint file with new-flow traceability marker → 0.
#
# Crucially, the helper MUST NOT touch any file under .yoke/sprints/
# during legacy detection — assert via mtime comparison.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: legacy-detect violation: %s\n' "$1" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SLUG="2026-01-01-test-task"

write_active_pointer() {
  mkdir -p "${TMP_DIR}/.yoke/runtime"
  printf '%s' "$SLUG" > "${TMP_DIR}/.yoke/runtime/.current"
}

write_legacy_ac() {
  mkdir -p "${TMP_DIR}/.yoke/acceptance-contracts"
  cat > "${TMP_DIR}/.yoke/acceptance-contracts/${SLUG}.md" <<'EOF'
# AC (legacy): test
> Status: ratified
EOF
}

write_legacy_sprint_file() {
  local n="$1"
  mkdir -p "${TMP_DIR}/.yoke/sprints"
  cat > "${TMP_DIR}/.yoke/sprints/${SLUG}-s$(printf '%02d' "$n").md" <<EOF
---
task_id: ${SLUG}-s$(printf '%02d' "$n")
sprint: ${n}
slug: ${SLUG}
status: approved
created_at: 2026-01-01
model: ""
traceability: ".yoke/specs/${SLUG}.md"
---

# Sprint $(printf '%02d' "$n") of 01: legacy

## Sprint objective
legacy.
EOF
}

write_new_flow_sprint_file() {
  local n="$1"
  mkdir -p "${TMP_DIR}/.yoke/sprints"
  cat > "${TMP_DIR}/.yoke/sprints/${SLUG}-s$(printf '%02d' "$n").md" <<EOF
---
task_id: ${SLUG}-s$(printf '%02d' "$n")
sprint: ${n}
slug: ${SLUG}
status: draft
created_at: 2026-01-01
model: ""
traceability: ".yoke/specs/${SLUG}.md; .yoke/acceptance-criteria/${SLUG}.md"
---

# Sprint $(printf '%02d' "$n") of 01: new flow

## Sprint objective
new.
EOF
}

clear_fixture() {
  rm -rf "${TMP_DIR}/.yoke"
}

run_detect() {
  ( cd "$TMP_DIR" && \
    set +u && \
    source "${REPO_ROOT}/lib/generate-sprints/legacy-detect.sh" && \
    legacy_detect "$SLUG" )
}

# --- Branch 1: new-flow task with no legacy AC, no sprint files -----------

clear_fixture
write_active_pointer
set +e
run_detect 2>"${TMP_DIR}/.stderr"
rc=$?
set -e
[[ "$rc" -eq 0 ]] \
  || violation "expected rc=0 on new-flow (no AC, no sprints); got ${rc}"
[[ ! -s "${TMP_DIR}/.stderr" ]] \
  || violation "expected empty stderr on new-flow path"
printf 'PASS: new-flow task accepted (no legacy AC, no sprint files)\n'

# --- Branch 2: legacy AC archive present → reject -------------------------

clear_fixture
write_active_pointer
write_legacy_ac
set +e
run_detect 2>"${TMP_DIR}/.stderr"
rc=$?
set -e
[[ "$rc" -eq 1 ]] \
  || violation "expected rc=1 on legacy-AC fixture; got ${rc}"
if ! grep -qF "wm: legacy task — generate-sprints does not migrate" \
    "${TMP_DIR}/.stderr"; then
  cat "${TMP_DIR}/.stderr" >&2
  violation "stderr did not contain literal rejection message (legacy AC branch)"
fi
printf 'PASS: legacy AC archive triggers rejection\n'

# --- Branch 3: legacy sprint file (no new-flow marker) → reject -----------

clear_fixture
write_active_pointer
write_legacy_sprint_file 1
# Capture pre-detection mtime to assert untouched.
mtime_before=$(stat -f %m "${TMP_DIR}/.yoke/sprints/${SLUG}-s01.md" 2>/dev/null \
  || stat -c %Y "${TMP_DIR}/.yoke/sprints/${SLUG}-s01.md")
sleep 1  # ensure mtime granularity
set +e
run_detect 2>"${TMP_DIR}/.stderr"
rc=$?
set -e
mtime_after=$(stat -f %m "${TMP_DIR}/.yoke/sprints/${SLUG}-s01.md" 2>/dev/null \
  || stat -c %Y "${TMP_DIR}/.yoke/sprints/${SLUG}-s01.md")
[[ "$rc" -eq 1 ]] \
  || violation "expected rc=1 on legacy-sprint-file fixture; got ${rc}"
if ! grep -qF "wm: legacy task — generate-sprints does not migrate" \
    "${TMP_DIR}/.stderr"; then
  cat "${TMP_DIR}/.stderr" >&2
  violation "stderr did not contain literal rejection message (legacy sprint branch)"
fi
[[ "$mtime_before" -eq "$mtime_after" ]] \
  || violation "legacy sprint file's mtime changed during detection (must be untouched)"
printf 'PASS: legacy sprint file triggers rejection without mtime touch\n'

# --- Branch 4: new-flow sprint file with marker → accept ------------------

clear_fixture
write_active_pointer
write_new_flow_sprint_file 1
set +e
run_detect 2>"${TMP_DIR}/.stderr"
rc=$?
set -e
[[ "$rc" -eq 0 ]] \
  || violation "expected rc=0 on new-flow sprint file with marker; got ${rc}"
[[ ! -s "${TMP_DIR}/.stderr" ]] \
  || violation "expected empty stderr on new-flow marker path"
printf 'PASS: new-flow sprint file with marker accepted\n'

printf 'PASS: legacy task rejected, sprints untouched\n'
exit 0
