#!/usr/bin/env bash
# shellcheck shell=bash
#
# render-bundle.test.sh — Sprint 03 / Task t03 happy-path unit test
# (US-005 render stage, AC-005-1 / AC-005-3 / AC-005-4).
#
# Asserts that `lib/generate-sprints/render-bundle.sh::render_sprint_bundle`:
#   1. Produces a runtime bundle at `.yoke/sprints/<slug>-s<NN>.md`
#      conforming to `templates/sprint.md` (5 H2 headings present, in
#      fixed order).
#   2. Each `### Task <ID>` subsection carries the four inline labels
#      (`**Story:**`, `**Technical implementation:**`, `**Validation:**`,
#      `**Acceptance criterion:**`).
#   3. Each `**Story:**` line ends with a `(Realizes: US-NNN[, US-MMM])`
#      clause matching the regex `\(Realizes: US-[0-9]{3}(, US-[0-9]{3})*\)`.
#   4. Frontmatter `traceability` cites both spec and AC paths,
#      semicolon-separated.
#
# Test contract:
#   - exit 0 with `PASS:` lines on success.
#   - exit non-zero with `wm: render violation:`-prefixed stderr
#     naming the failed assertion otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: render violation: %s\n' "$1" >&2
  exit 1
}

# Watchdog.
( sleep 600 && kill -TERM $$ ) &
WATCHDOG_PID=$!
trap 'kill -TERM "$WATCHDOG_PID" 2>/dev/null || true' EXIT

# Isolated tmp dir.
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"; kill -TERM "$WATCHDOG_PID" 2>/dev/null || true' EXIT

cd "$TMP_ROOT"

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/working-memory/paths.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/plan-io.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/partition.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/generate-sprints/render-bundle.sh"

SLUG="2026-01-01-bar"

# --- Bootstrap: 3-task plan, single sprint (all share 2 anchors) -----------

init_plan_file "$SLUG" >/dev/null

PLAN_PATH="${TMP_ROOT}/.yoke/runtime/.generate-sprints-plan.yaml"

python3 - "$PLAN_PATH" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    plan = yaml.safe_load(f)
plan["tasks"] = [
    {
        "task_id": "T-1",
        "realizes_user_stories": ["US-001", "US-002"],
        "applies_decisions": ["paths.sh", "templates/sprint.md"],
        "story": "Add a happy-path unit test for the renderer.",
        "technical_implementation": "Drop a tests/runtime/render-bundle.test.sh "
            "watchdog-protected script that runs against a synthetic plan.",
        "validation": "bash tests/runtime/render-bundle.test.sh exits 0.",
        "instructions": "Add a happy-path unit test for the renderer.\n\n"
            "Drop a tests/runtime/render-bundle.test.sh watchdog-protected "
            "script that runs against a synthetic plan.\n\n"
            "bash tests/runtime/render-bundle.test.sh exits 0.",
        "sensors": ["lint", "tests-runtime"],
        "acceptance_criterion": "Bundle file shape conforms.",
    },
    {
        "task_id": "T-2",
        "realizes_user_stories": ["US-001"],
        "applies_decisions": ["paths.sh", "templates/sprint.md"],
        "instructions": "Wire the helper into the skill body.",
        "sensors": ["tests-runtime"],
        "acceptance_criterion": "Skill body cites the helper.",
    },
    {
        "task_id": "T-3",
        "realizes_user_stories": ["US-003"],
        "applies_decisions": ["paths.sh", "templates/sprint.md"],
        "instructions": "Document the lineage.",
        "sensors": [],
        "acceptance_criterion": "Lineage doc updated.",
    },
]
with open(path, "w") as f:
    yaml.safe_dump(plan, f, default_flow_style=False, sort_keys=False)
PY

partition_tasks "$PLAN_PATH" \
  || violation "partition_tasks failed before render"

# Sanity: 1 sprint, 3 tasks.
P_LEN="$(yq -r '.sprint_partition | length' "$PLAN_PATH")"
[[ "$P_LEN" == "1" ]] || violation "expected 1 sprint pre-render, got $P_LEN"

# --- Render sprint 1 --------------------------------------------------------

render_sprint_bundle "$SLUG" 1 "$PLAN_PATH" \
  || violation "render_sprint_bundle exited non-zero"

BUNDLE_PATH="${TMP_ROOT}/.yoke/sprints/${SLUG}-s01.md"
[[ -f "$BUNDLE_PATH" ]] \
  || violation "expected bundle at $BUNDLE_PATH, missing"

# --- Assert 5 H2 headings present and ordered -------------------------------

python3 - "$BUNDLE_PATH" <<'PY' || exit 1
import sys
required = [
    "## Sprint objective",
    "## Sprint DoD",
    "## Tasks",
    "## Functional acceptance criteria",
    "## Sensors",
]
with open(sys.argv[1]) as f:
    body = f.read()
last = -1
for h in required:
    idx = body.find(h)
    if idx < 0 or idx <= last:
        print(f"wm: render violation: H2 {h!r} missing or out of order", file=sys.stderr)
        sys.exit(1)
    last = idx
PY

printf 'PASS: 5 H2 headings present and ordered\n'

# --- Assert 4 inline labels per task subsection -----------------------------

LABEL_COUNTS="$(python3 - "$BUNDLE_PATH" <<'PY'
import re, sys
with open(sys.argv[1]) as f:
    body = f.read()
labels = ["**Story:**", "**Technical implementation:**", "**Validation:**", "**Acceptance criterion:**"]
counts = {l: body.count(l) for l in labels}
for l, c in counts.items():
    print(f"{l}={c}")
PY
)"
echo "$LABEL_COUNTS" | grep -q '\*\*Story:\*\*=3'              || violation "Story label count != 3"
echo "$LABEL_COUNTS" | grep -q '\*\*Technical implementation:\*\*=3' || violation "Technical implementation label count != 3"
echo "$LABEL_COUNTS" | grep -q '\*\*Validation:\*\*=3'         || violation "Validation label count != 3"
echo "$LABEL_COUNTS" | grep -q '\*\*Acceptance criterion:\*\*=3' || violation "Acceptance criterion label count != 3"

printf 'PASS: 4 inline labels per task (3 tasks × 4 labels)\n'

# --- Assert (Realizes: US-NNN) clause adjacent to every Story line ----------

if ! grep -E '\*\*Story:\*\* .* \(Realizes: US-[0-9]{3}(, US-[0-9]{3})*\)' "$BUNDLE_PATH" >/dev/null; then
  violation "Realizes clause regex did not match any Story line"
fi
STORY_LINES="$(grep -c '^\*\*Story:\*\*' "$BUNDLE_PATH")"
REALIZES_LINES="$(grep -cE '^\*\*Story:\*\* .* \(Realizes: US-[0-9]{3}' "$BUNDLE_PATH")"
[[ "$STORY_LINES" == "$REALIZES_LINES" ]] \
  || violation "Story lines: $STORY_LINES, with Realizes clause: $REALIZES_LINES (mismatch)"

printf 'PASS: (Realizes: US-NNN) clause on every Story line\n'

# --- Assert frontmatter traceability cites both spec and AC paths -----------

grep -qE "^traceability: \".*\.yoke/specs/${SLUG}\.md.*\.yoke/acceptance-criteria/${SLUG}\.md.*\"$" "$BUNDLE_PATH" \
  || violation "frontmatter traceability missing both spec and AC paths"

printf 'PASS: frontmatter traceability cites spec + AC (semicolon-joined)\n'

# --- Assert frontmatter status is draft (Trigger 2.5 pre-flip) --------------

grep -qE '^status: draft$' "$BUNDLE_PATH" \
  || violation "frontmatter status not 'draft' (expected pre-Trigger-2.5 state)"

printf 'PASS: frontmatter status: draft\n'

# --- Assert ## Functional acceptance criteria lists US-IDs ------------------

# The 3 tasks realise US-001, US-002, US-003 — union should appear under FAC.
FAC_BLOCK="$(awk '/^## Functional acceptance criteria$/,/^## Sensors$/' "$BUNDLE_PATH")"
echo "$FAC_BLOCK" | grep -q "US-001" || violation "FAC missing US-001"
echo "$FAC_BLOCK" | grep -q "US-002" || violation "FAC missing US-002"
echo "$FAC_BLOCK" | grep -q "US-003" || violation "FAC missing US-003"

printf 'PASS: ## Functional acceptance criteria lists US-001, US-002, US-003\n'

# --- Assert ## Sensors lists deduplicated sensor IDs ------------------------

SENSORS_BLOCK="$(awk '/^## Sensors$/,/^---$/' "$BUNDLE_PATH")"
echo "$SENSORS_BLOCK" | grep -q "lint"          || violation "Sensors missing 'lint'"
echo "$SENSORS_BLOCK" | grep -q "tests-runtime" || violation "Sensors missing 'tests-runtime'"
SENSOR_LINT_COUNT="$(echo "$SENSORS_BLOCK" | grep -c '^- lint$')"
[[ "$SENSOR_LINT_COUNT" == "1" ]] \
  || violation "Sensor 'lint' duplicated (count=$SENSOR_LINT_COUNT, expected 1)"

printf 'PASS: ## Sensors lists deduplicated IDs\n'

exit 0
