#!/usr/bin/env bash
# tests/sensor-tiering.test.sh
#
# Sensor-cost-tiering invariants (Part 1 of 5).
#
# Part 1 — foundation: per-sensor template + project-scoped
# `wm_sensors_dir`/`wm_sensor_path` helpers + Acceptance Contract
# references sensors by id (no inline command / tier / class).
#
# Subsequent parts extend this file:
#   Part 2 — `/yoke:ack-sensors --mode upsert` (create / update / preserve)
#   Part 3 — `hooks/verify-acceptance.sh --tier` filter
#   Part 4 — Validator `schedule_next` emission + persistence
#   Part 5 — Coordinator two-phase per-cycle + runs-history persistence
#
# Source PRD: .vibeflow/prds/sensor-cost-tiering.md

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (a) templates/sensor.md exists and carries the required frontmatter
# ---------------------------------------------------------------------
SENSOR_TPL="$PLUGIN_ROOT/templates/sensor.md"

if [ -f "$SENSOR_TPL" ]; then
  pass "(a) templates/sensor.md exists"
else
  err "(a) templates/sensor.md is missing"
fi

# Extract the YAML frontmatter (between the first two `---` lines).
sensor_fm=$(awk '
  /^---$/ { count++; next }
  count == 1 { print }
' "$SENSOR_TPL" 2>/dev/null || true)

required_fm_keys=(id command class tier applies_to runs)
missing_fm=()
for key in "${required_fm_keys[@]}"; do
  if ! printf '%s\n' "$sensor_fm" | grep -qE "^${key}:"; then
    missing_fm+=("$key")
  fi
done

if [ "${#missing_fm[@]}" -eq 0 ]; then
  pass "(a) templates/sensor.md frontmatter has all required keys: ${required_fm_keys[*]}"
else
  err "(a) templates/sensor.md frontmatter missing keys: ${missing_fm[*]}"
fi

# Required body sections.
if grep -qE '^## Caveats$' "$SENSOR_TPL"; then
  pass "(a) templates/sensor.md has '## Caveats' section"
else
  err "(a) templates/sensor.md is missing '## Caveats' section"
fi

if grep -qE '^## Calibration notes$' "$SENSOR_TPL"; then
  pass "(a) templates/sensor.md has '## Calibration notes' section"
else
  err "(a) templates/sensor.md is missing '## Calibration notes' section"
fi

# ---------------------------------------------------------------------
# (b) wm_sensors_dir + wm_sensor_path resolve correctly
# ---------------------------------------------------------------------
# shellcheck source=/dev/null
source "$PLUGIN_ROOT/lib/working-memory/paths.sh"

actual_sensors_dir="$(wm_sensors_dir)"
if [ "$actual_sensors_dir" = ".yoke/sensors" ]; then
  pass "(b) wm_sensors_dir returns .yoke/sensors"
else
  err "(b) wm_sensors_dir returned '$actual_sensors_dir' (expected .yoke/sensors)"
fi

actual_sensor_path="$(wm_sensor_path "playwright-checkout" 2>/dev/null || true)"
if [ "$actual_sensor_path" = ".yoke/sensors/playwright-checkout.md" ]; then
  pass "(b) wm_sensor_path 'playwright-checkout' returns .yoke/sensors/playwright-checkout.md"
else
  err "(b) wm_sensor_path returned '$actual_sensor_path' (expected .yoke/sensors/playwright-checkout.md)"
fi

# Invalid id: empty
if wm_sensor_path "" 2>/dev/null; then
  err "(b) wm_sensor_path accepted empty id (should fail)"
else
  pass "(b) wm_sensor_path rejects empty id"
fi

# Invalid id: starts with a hyphen
if wm_sensor_path "-bad-start" 2>/dev/null; then
  err "(b) wm_sensor_path accepted id starting with hyphen (should fail)"
else
  pass "(b) wm_sensor_path rejects id starting with hyphen"
fi

# Invalid id: contains a slash (path traversal guard)
if wm_sensor_path "evil/../escape" 2>/dev/null; then
  err "(b) wm_sensor_path accepted id with slash (should fail)"
else
  pass "(b) wm_sensor_path rejects id with slash"
fi

# Valid id with allowed punctuation: dots, dashes, underscores
if path_with_dots="$(wm_sensor_path "playwright.checkout_v1-2" 2>/dev/null)"; then
  if [ "$path_with_dots" = ".yoke/sensors/playwright.checkout_v1-2.md" ]; then
    pass "(b) wm_sensor_path accepts dots, underscores, hyphens"
  else
    err "(b) wm_sensor_path returned '$path_with_dots' for valid id"
  fi
else
  err "(b) wm_sensor_path rejected valid id 'playwright.checkout_v1-2'"
fi

# ---------------------------------------------------------------------
# (c) templates/acceptance-contract.md references sensors by id only
# ---------------------------------------------------------------------
CONTRACT_TPL="$PLUGIN_ROOT/templates/acceptance-contract.md"

if [ -f "$CONTRACT_TPL" ]; then
  pass "(c) templates/acceptance-contract.md exists"
else
  err "(c) templates/acceptance-contract.md is missing"
fi

# Sensors registry section is present.
if grep -qE '^## Sensors registry$' "$CONTRACT_TPL"; then
  pass "(c) acceptance-contract.md has '## Sensors registry' section"
else
  err "(c) acceptance-contract.md is missing '## Sensors registry' section"
fi

# Registry block declares sensors with id + command + class.
registry_block=$(awk '
  /^```yaml$/ { in_block = 1; next }
  /^```$/ && in_block { in_block = 0 }
  in_block { print }
' "$CONTRACT_TPL" 2>/dev/null || true)

for key in "id:" "command:" "class:"; do
  if printf '%s\n' "$registry_block" | grep -qF "$key"; then
    pass "(c) Sensors registry block declares '$key'"
  else
    err "(c) Sensors registry block missing '$key'"
  fi
done

# Anti-inline check: scenarios reference sensors by id only — no
# `linter:` / `unit:` / `type-check:` / `structural:` per-bullet inline
# command declarations like the pre-Part-1 layout used.
inline_hits=$(grep -nE '^- (linter|type-check|structural|unit): `' "$CONTRACT_TPL" || true)
if [ -z "$inline_hits" ]; then
  pass "(c) acceptance-contract.md has no inline sensor-command bullets"
else
  err "(c) acceptance-contract.md still has inline sensor-command bullets:"
  printf '%s\n' "$inline_hits" | sed 's/^/    /' >&2
fi

# Anti-inline check: scenarios should not declare `tier:` directly.
contract_tier_hits=$(grep -nE '^[[:space:]]*tier:' "$CONTRACT_TPL" || true)
if [ -z "$contract_tier_hits" ]; then
  pass "(c) acceptance-contract.md has no inline 'tier:' declarations"
else
  err "(c) acceptance-contract.md has inline 'tier:' declarations:"
  printf '%s\n' "$contract_tier_hits" | sed 's/^/    /' >&2
fi

# Scenario `Sensors:` entries should reference ids (placeholder is
# `<sensor-id>` in the template, but the bracket form must remain).
if grep -qE '^Sensors: \[' "$CONTRACT_TPL"; then
  pass "(c) acceptance-contract.md retains 'Sensors: [<id>...]' shape"
else
  err "(c) acceptance-contract.md is missing 'Sensors: [<id>...]' references"
fi

# ---------------------------------------------------------------------
# (d) /yoke:ack-sensors --mode upsert: create / update / idempotency
# ---------------------------------------------------------------------
ACK_SENSORS="$PLUGIN_ROOT/lib/sensors/ack-sensors.sh"

# Build a fixture contract referencing 4 sensors:
#   linter-ruff   (computational, default cheap)
#   unit-pytest   (computational, default cheap)
#   judge-voice   (inferential,   default expensive)
#   playwright-e2e (computational; author will override to expensive)
TMP_PART2=$(mktemp -d)
trap 'rm -rf "$TMP_PART2"' EXIT

cat > "$TMP_PART2/contract.md" <<'CONTRACT'
# Acceptance Contract — fixture-task

> Status: ratified

## Use cases (BDD scenarios)

### Scenario 1 — fixture s01-t01
Task: 2026-04-27-fixture-s01-t01
Given x
When y
Then z
Fixture: none
Sensors: [linter-ruff, unit-pytest]

### Scenario 2 — fixture s01-t02
Task: 2026-04-27-fixture-s01-t02
Given x
When y
Then z
Fixture: none
Sensors: [unit-pytest, playwright-e2e]

### Scenario 3 — fixture s01-t03
Task: 2026-04-27-fixture-s01-t03
Given x
When y
Then z
Fixture: none
Sensors: [judge-voice]

## Sensors registry

```yaml
sensors:
  - id: linter-ruff
    command: ruff check
    class: computational
  - id: unit-pytest
    command: pytest -q
    class: computational
  - id: judge-voice
    command: bash agents/semantic-judge/voice.sh
    class: inferential
  - id: playwright-e2e
    command: npx playwright test
    class: computational
```
CONTRACT

# Create case: empty .yoke/sensors/, run upsert, files materialize.
(
  cd "$TMP_PART2"
  bash "$ACK_SENSORS" --mode upsert "$TMP_PART2/contract.md" >/dev/null
)

for id in linter-ruff unit-pytest judge-voice playwright-e2e; do
  if [ -f "$TMP_PART2/.yoke/sensors/${id}.md" ]; then
    pass "(d) upsert created .yoke/sensors/${id}.md"
  else
    err "(d) upsert did not create .yoke/sensors/${id}.md"
  fi
done

# Class-based default tier check.
ruff_tier=$(awk -F': ' '/^tier:/ { print $2; exit }' "$TMP_PART2/.yoke/sensors/linter-ruff.md" 2>/dev/null || true)
if [ "$ruff_tier" = "cheap" ]; then
  pass "(d) computational sensor 'linter-ruff' defaulted to tier: cheap"
else
  err "(d) computational sensor 'linter-ruff' expected tier=cheap, got '${ruff_tier}'"
fi

judge_tier=$(awk -F': ' '/^tier:/ { print $2; exit }' "$TMP_PART2/.yoke/sensors/judge-voice.md" 2>/dev/null || true)
if [ "$judge_tier" = "expensive" ]; then
  pass "(d) inferential sensor 'judge-voice' defaulted to tier: expensive"
else
  err "(d) inferential sensor 'judge-voice' expected tier=expensive, got '${judge_tier}'"
fi

# applies_to is populated from scenario references.
ruff_applies=$(awk -F': ' '/^applies_to:/ { sub(/^applies_to:[[:space:]]*/, "", $0); print $0; exit }' "$TMP_PART2/.yoke/sensors/linter-ruff.md" 2>/dev/null || true)
if [[ "$ruff_applies" == *"2026-04-27-fixture-s01-t01"* ]]; then
  pass "(d) linter-ruff applies_to includes referencing task id"
else
  err "(d) linter-ruff applies_to is missing referencing task id (got '${ruff_applies}')"
fi

# Update case: hand-edit a sensor file (override tier, add caveat),
# re-run upsert with a contract that gives it new applies_to,
# and confirm: applies_to refreshed; tier override + caveat preserved.
PW="$TMP_PART2/.yoke/sensors/playwright-e2e.md"
# Override tier inside the frontmatter
awk '
  BEGIN { fm = 0 }
  /^---[[:space:]]*$/ { fm++; print; next }
  fm == 1 && /^tier:/ { print "tier: expensive"; next }
  { print }
' "$PW" > "$PW.new" && mv "$PW.new" "$PW"

# Add author caveat in body.
printf '\n## Caveats\n- Times out under 30 s when test DB is cold.\n' >> "$PW"

# Modify the contract to expand playwright-e2e's applies_to.
cat > "$TMP_PART2/contract.md" <<'CONTRACT'
# Acceptance Contract — fixture-task

> Status: ratified

## Use cases (BDD scenarios)

### Scenario 1 — fixture s01-t01
Task: 2026-04-27-fixture-s01-t01
Given x
When y
Then z
Fixture: none
Sensors: [linter-ruff, unit-pytest, playwright-e2e]

### Scenario 2 — fixture s01-t02
Task: 2026-04-27-fixture-s01-t02
Given x
When y
Then z
Fixture: none
Sensors: [unit-pytest, playwright-e2e]

### Scenario 3 — fixture s01-t03
Task: 2026-04-27-fixture-s01-t03
Given x
When y
Then z
Fixture: none
Sensors: [judge-voice]

## Sensors registry

```yaml
sensors:
  - id: linter-ruff
    command: ruff check
    class: computational
  - id: unit-pytest
    command: pytest -q
    class: computational
  - id: judge-voice
    command: bash agents/semantic-judge/voice.sh
    class: inferential
  - id: playwright-e2e
    command: npx playwright test
    class: computational
```
CONTRACT

(
  cd "$TMP_PART2"
  bash "$ACK_SENSORS" --mode upsert "$TMP_PART2/contract.md" >/dev/null
)

# applies_to expanded to include the new task id.
pw_applies=$(awk -F': ' '/^applies_to:/ { sub(/^applies_to:[[:space:]]*/, "", $0); print $0; exit }' "$PW" 2>/dev/null || true)
if [[ "$pw_applies" == *"2026-04-27-fixture-s01-t01"* && "$pw_applies" == *"2026-04-27-fixture-s01-t02"* ]]; then
  pass "(d) upsert refreshed playwright-e2e applies_to with both task ids"
else
  err "(d) upsert did not expand playwright-e2e applies_to (got '${pw_applies}')"
fi

# Tier override preserved.
pw_tier=$(awk -F': ' '/^tier:/ { print $2; exit }' "$PW" 2>/dev/null || true)
if [ "$pw_tier" = "expensive" ]; then
  pass "(d) upsert preserved author tier override (expensive) on update"
else
  err "(d) upsert clobbered author tier override (got '${pw_tier}')"
fi

# Author caveat preserved verbatim.
if grep -qF "Times out under 30 s when test DB is cold." "$PW"; then
  pass "(d) upsert preserved author caveat in body"
else
  err "(d) upsert clobbered author caveat"
fi

# Idempotency: running upsert again with no contract changes is a no-op.
pre_hash=$(LC_ALL=C find "$TMP_PART2/.yoke/sensors" -type f -name '*.md' \
            -exec sha256sum {} \; 2>/dev/null | LC_ALL=C sort)
(
  cd "$TMP_PART2"
  bash "$ACK_SENSORS" --mode upsert "$TMP_PART2/contract.md" >/dev/null
)
post_hash=$(LC_ALL=C find "$TMP_PART2/.yoke/sensors" -type f -name '*.md' \
             -exec sha256sum {} \; 2>/dev/null | LC_ALL=C sort)

if [ "$pre_hash" = "$post_hash" ]; then
  pass "(d) upsert is idempotent (no file changes on second run)"
else
  err "(d) upsert is NOT idempotent — file content changed on second run"
fi

# ---------------------------------------------------------------------
# (e) /yoke:ack-sensors --mode readiness: file-existence + parse checks
# ---------------------------------------------------------------------

# Happy path: all sensor files exist + parse → status: ready, exit 0.
if (cd "$TMP_PART2" && bash "$ACK_SENSORS" --mode readiness "$TMP_PART2/contract.md" >/dev/null 2>&1); then
  pass "(e) readiness reports ready when all sensor files exist + parse"
else
  err "(e) readiness reported not-ready unexpectedly"
fi

# Failure path: delete one sensor file → readiness must fail with
# structured violation pointing at the missing file.
rm "$TMP_PART2/.yoke/sensors/judge-voice.md"
ready_out="$(cd "$TMP_PART2" && bash "$ACK_SENSORS" --mode readiness "$TMP_PART2/contract.md" 2>&1 || true)"
ready_exit=$(cd "$TMP_PART2" && bash "$ACK_SENSORS" --mode readiness "$TMP_PART2/contract.md" >/dev/null 2>&1; echo $?)

if [ "$ready_exit" -eq 4 ]; then
  pass "(e) readiness exits 4 when a sensor file is missing"
else
  err "(e) readiness expected exit 4 on missing sensor, got '${ready_exit}'"
fi

if printf '%s' "$ready_out" | grep -qE 'status:[[:space:]]+not-ready'; then
  pass "(e) readiness reports status: not-ready on missing sensor"
else
  err "(e) readiness did not surface status: not-ready"
fi

if printf '%s' "$ready_out" | grep -qF 'sensor: "judge-voice"'; then
  pass "(e) readiness names the missing sensor in failures"
else
  err "(e) readiness did not name the missing sensor"
fi

if printf '%s' "$ready_out" | grep -qF '/yoke:ack-sensors --mode upsert'; then
  pass "(e) readiness suggests \`/yoke:ack-sensors --mode upsert\` correction"
else
  err "(e) readiness did not include the upsert correction instruction"
fi

# ---------------------------------------------------------------------
# (f) Upsert validation: unregistered reference → structured failure
# ---------------------------------------------------------------------
TMP_PART2_BAD=$(mktemp -d)
cat > "$TMP_PART2_BAD/contract.md" <<'CONTRACT'
# Acceptance Contract — bad fixture

> Status: ratified

## Use cases (BDD scenarios)

### Scenario 1 — bad
Task: 2026-04-27-bad-s01-t01
Given x
When y
Then z
Fixture: none
Sensors: [phantom-sensor]

## Sensors registry

```yaml
sensors:
  - id: linter-ruff
    command: ruff check
    class: computational
```
CONTRACT

bad_out="$(cd "$TMP_PART2_BAD" && bash "$ACK_SENSORS" --mode upsert "$TMP_PART2_BAD/contract.md" 2>&1 || true)"
bad_exit=$(cd "$TMP_PART2_BAD" && bash "$ACK_SENSORS" --mode upsert "$TMP_PART2_BAD/contract.md" >/dev/null 2>&1; echo $?)

if [ "$bad_exit" -eq 4 ]; then
  pass "(f) upsert exits 4 on unregistered sensor reference"
else
  err "(f) upsert expected exit 4 on unregistered reference, got '${bad_exit}'"
fi

if printf '%s' "$bad_out" | grep -qF 'phantom-sensor'; then
  pass "(f) upsert names the unregistered sensor id in failures"
else
  err "(f) upsert did not name the unregistered sensor"
fi

rm -rf "$TMP_PART2_BAD"

# ---------------------------------------------------------------------
# (g) hooks/verify-acceptance.sh --tier filter (Part 3)
# ---------------------------------------------------------------------
HOOK="$PLUGIN_ROOT/hooks/verify-acceptance.sh"

# Re-run upsert to restore judge-voice.md (deleted earlier in (e)).
(
  cd "$TMP_PART2"
  bash "$ACK_SENSORS" --mode upsert "$TMP_PART2/contract.md" >/dev/null
)

# Sanity: all 4 sensor files exist before the hook tests.
for id in linter-ruff unit-pytest judge-voice playwright-e2e; do
  if [ -f "$TMP_PART2/.yoke/sensors/${id}.md" ]; then
    pass "(g) sensor file present pre-hook: ${id}"
  else
    err "(g) missing sensor file pre-hook: ${id}"
  fi
done

# Default behavior preserved: no --tier flag → all sensors invoked.
hook_default="$(cd "$TMP_PART2" && bash "$HOOK" "$TMP_PART2/contract.md" 2>/dev/null || true)"
default_count=$(printf '%s\n' "$hook_default" | grep -c '^  - sensor:' || true)
if [ "$default_count" -eq 4 ]; then
  pass "(g) default (no --tier) ran all 4 sensors"
else
  err "(g) default expected 4 sensor entries, got ${default_count}"
fi

# --tier all is explicit and equivalent to omitting the flag.
hook_all="$(cd "$TMP_PART2" && bash "$HOOK" --tier all "$TMP_PART2/contract.md" 2>/dev/null || true)"
all_count=$(printf '%s\n' "$hook_all" | grep -c '^  - sensor:' || true)
if [ "$all_count" -eq 4 ]; then
  pass "(g) --tier all ran all 4 sensors"
else
  err "(g) --tier all expected 4 sensor entries, got ${all_count}"
fi

# --tier cheap: 2 cheap sensors (linter-ruff, unit-pytest) — playwright-e2e
# was overridden to expensive in (d); judge-voice is inferential→expensive.
hook_cheap="$(cd "$TMP_PART2" && bash "$HOOK" --tier cheap "$TMP_PART2/contract.md" 2>/dev/null || true)"
if printf '%s' "$hook_cheap" | grep -qF 'sensor: "linter-ruff"' \
   && printf '%s' "$hook_cheap" | grep -qF 'sensor: "unit-pytest"'; then
  pass "(g) --tier cheap includes computational-cheap sensors"
else
  err "(g) --tier cheap missing expected cheap sensors"
fi

if printf '%s' "$hook_cheap" | grep -qF 'sensor: "judge-voice"'; then
  err "(g) --tier cheap leaked inferential sensor judge-voice"
else
  pass "(g) --tier cheap excludes inferential sensor judge-voice"
fi

if printf '%s' "$hook_cheap" | grep -qF 'sensor: "playwright-e2e"'; then
  err "(g) --tier cheap leaked overridden-expensive sensor playwright-e2e"
else
  pass "(g) --tier cheap excludes overridden-expensive playwright-e2e"
fi

# --tier expensive: judge-voice (inferential default) + playwright-e2e
# (overridden) — 2 expensive sensors.
hook_expensive="$(cd "$TMP_PART2" && bash "$HOOK" --tier expensive "$TMP_PART2/contract.md" 2>/dev/null || true)"
if printf '%s' "$hook_expensive" | grep -qF 'sensor: "judge-voice"' \
   && printf '%s' "$hook_expensive" | grep -qF 'sensor: "playwright-e2e"'; then
  pass "(g) --tier expensive includes inferential + overridden-expensive sensors"
else
  err "(g) --tier expensive missing expected expensive sensors"
fi

if printf '%s' "$hook_expensive" | grep -qF 'sensor: "linter-ruff"'; then
  err "(g) --tier expensive leaked cheap sensor linter-ruff"
else
  pass "(g) --tier expensive excludes cheap sensor linter-ruff"
fi

# Intersection with --criterion: only sensors that apply to the criterion
# AND match the tier. Scenario 1 maps to linter-ruff + unit-pytest +
# playwright-e2e (after Part-2's contract update). With --tier cheap we
# expect just linter-ruff + unit-pytest.
hook_combined="$(cd "$TMP_PART2" && bash "$HOOK" --tier cheap --criterion 'Scenario 1' "$TMP_PART2/contract.md" 2>/dev/null || true)"
combined_count=$(printf '%s\n' "$hook_combined" | grep -c '^  - sensor:' || true)
if [ "$combined_count" -eq 2 ]; then
  pass "(g) --tier cheap + --criterion Scenario 1 intersected to 2 sensors"
else
  err "(g) intersection expected 2 sensors, got ${combined_count}"
fi
if printf '%s' "$hook_combined" | grep -qF 'sensor: "linter-ruff"' \
   && printf '%s' "$hook_combined" | grep -qF 'sensor: "unit-pytest"'; then
  pass "(g) intersection includes the right sensors"
else
  err "(g) intersection missing expected sensors"
fi

# Empty intersection: --tier expensive + criterion that maps only cheap
# sensors → 0 sensors, exit 0. We use Scenario 1 above which contains
# playwright-e2e (expensive) — so try Scenario 1 with --tier expensive
# and assert only playwright-e2e shows up. Then build a new criterion
# that maps only cheap.

# Use a synthetic case: --criterion 'Scenario 3' (judge-voice only) with
# --tier cheap → 0 sensors.
hook_empty="$(cd "$TMP_PART2" && bash "$HOOK" --tier cheap --criterion 'Scenario 3' "$TMP_PART2/contract.md" 2>/dev/null || true)"
empty_count=$(printf '%s\n' "$hook_empty" | grep -c '^  - sensor:' || true)
if [ "$empty_count" -eq 0 ]; then
  pass "(g) empty intersection produces 0 sensor entries"
else
  err "(g) empty intersection expected 0 sensors, got ${empty_count}"
fi
empty_exit=$(cd "$TMP_PART2" && bash "$HOOK" --tier cheap --criterion 'Scenario 3' "$TMP_PART2/contract.md" >/dev/null 2>&1; echo $?)
if [ "$empty_exit" -eq 0 ]; then
  pass "(g) empty intersection exits 0"
else
  err "(g) empty intersection expected exit 0, got ${empty_exit}"
fi

# Unknown --tier value → exit 2 with structured violation.
unknown_out="$(cd "$TMP_PART2" && bash "$HOOK" --tier slow "$TMP_PART2/contract.md" 2>&1 || true)"
unknown_exit=$(cd "$TMP_PART2" && bash "$HOOK" --tier slow "$TMP_PART2/contract.md" >/dev/null 2>&1; echo $?)
if [ "$unknown_exit" -eq 2 ]; then
  pass "(g) unknown --tier value exits 2"
else
  err "(g) unknown --tier expected exit 2, got ${unknown_exit}"
fi
if printf '%s' "$unknown_out" | grep -qF 'expected: cheap | expensive | all'; then
  pass "(g) unknown --tier emits structured violation with allowed set"
else
  err "(g) unknown --tier missing structured violation"
fi

# Missing sensor file under tier filter → exit 4 with structured violation.
rm "$TMP_PART2/.yoke/sensors/judge-voice.md"
miss_out="$(cd "$TMP_PART2" && bash "$HOOK" --tier expensive "$TMP_PART2/contract.md" 2>&1 || true)"
miss_exit=$(cd "$TMP_PART2" && bash "$HOOK" --tier expensive "$TMP_PART2/contract.md" >/dev/null 2>&1; echo $?)
if [ "$miss_exit" -eq 4 ]; then
  pass "(g) missing sensor file under --tier exits 4"
else
  err "(g) missing sensor file expected exit 4, got ${miss_exit}"
fi
if printf '%s' "$miss_out" | grep -qF 'judge-voice'; then
  pass "(g) missing-sensor violation names the offending id"
else
  err "(g) missing-sensor violation did not name offending id"
fi
if printf '%s' "$miss_out" | grep -qF '/yoke:ack-sensors --mode upsert'; then
  pass "(g) missing-sensor violation suggests upsert correction"
else
  err "(g) missing-sensor violation missing correction instruction"
fi

# Restore judge-voice.md so subsequent hook calls (if any) work.
(cd "$TMP_PART2" && bash "$ACK_SENSORS" --mode upsert "$TMP_PART2/contract.md" >/dev/null)

# ---------------------------------------------------------------------
# (h) old-format contracts: --tier cheap|expensive rejected; default OK
# ---------------------------------------------------------------------
TMP_OLD=$(mktemp -d)
cat > "$TMP_OLD/contract.md" <<'CONTRACT'
# Acceptance Contract — old format

## Sensors

### Computational
- shell-true: `true`
- shell-echo: `echo hello`
CONTRACT

# Default mode (no --tier) on old format still works.
old_default_exit=$(cd "$TMP_OLD" && bash "$HOOK" "$TMP_OLD/contract.md" >/dev/null 2>&1; echo $?)
if [ "$old_default_exit" -eq 0 ]; then
  pass "(h) old-format contract works with no --tier (backward compat)"
else
  err "(h) old-format default expected exit 0, got ${old_default_exit}"
fi

# --tier cheap on old format → exit 4 with structured violation.
old_tier_exit=$(cd "$TMP_OLD" && bash "$HOOK" --tier cheap "$TMP_OLD/contract.md" >/dev/null 2>&1; echo $?)
old_tier_out="$(cd "$TMP_OLD" && bash "$HOOK" --tier cheap "$TMP_OLD/contract.md" 2>&1 || true)"
if [ "$old_tier_exit" -eq 4 ]; then
  pass "(h) old-format with --tier cheap exits 4"
else
  err "(h) old-format with --tier cheap expected exit 4, got ${old_tier_exit}"
fi
if printf '%s' "$old_tier_out" | grep -qF "Sensors registry"; then
  pass "(h) old-format tier rejection names the new format"
else
  err "(h) old-format tier rejection missing new-format name"
fi
if printf '%s' "$old_tier_out" | grep -qF '/yoke:ack-sensors --mode upsert'; then
  pass "(h) old-format tier rejection suggests upsert correction"
else
  err "(h) old-format tier rejection missing correction instruction"
fi

rm -rf "$TMP_OLD"

# ---------------------------------------------------------------------
# (i) Validator persona — sensor-file reads + schedule_next contract
# ---------------------------------------------------------------------
VALIDATOR_MD="$PLUGIN_ROOT/agents/validator.md"

if [ -f "$VALIDATOR_MD" ]; then
  pass "(i) agents/validator.md exists"
else
  err "(i) agents/validator.md is missing"
fi

# Validator reads .yoke/sensors/<id>.md (Memory scope or persona body).
if grep -qE '\.yoke/sensors/<id>\.md' "$VALIDATOR_MD"; then
  pass "(i) validator persona references .yoke/sensors/<id>.md as a read"
else
  err "(i) validator persona does not reference .yoke/sensors/<id>.md"
fi

# Validator emits schedule_next per cycle with the locked shape.
if grep -qE '^- \*\*Emit `schedule_next:` per cycle' "$VALIDATOR_MD"; then
  pass "(i) validator persona requires schedule_next per cycle"
else
  err "(i) validator persona does not require schedule_next emission"
fi

for key in 'sensors:' 'tiers:' 'reason:'; do
  if grep -qF "$key" "$VALIDATOR_MD"; then
    pass "(i) validator schedule_next schema declares ${key}"
  else
    err "(i) validator schedule_next schema missing ${key}"
  fi
done

# Default rule is documented.
if grep -qE 'Always include `tier:cheap`' "$VALIDATOR_MD"; then
  pass "(i) validator persona documents 'cheap always' default rule"
else
  err "(i) validator persona missing 'cheap always' default rule"
fi

if grep -qE 'cheap-tier was green' "$VALIDATOR_MD"; then
  pass "(i) validator persona documents 'expensive when cheap-green' rule"
else
  err "(i) validator persona missing 'expensive when cheap-green' rule"
fi

# Cycle-1 heuristic.
if grep -qE 'Cycle-1 heuristic' "$VALIDATOR_MD"; then
  pass "(i) validator persona documents cycle-1 type-aware heuristic"
else
  err "(i) validator persona missing cycle-1 heuristic"
fi

# Actionable-feedback rationale + PRD reference.
if grep -qE 'shift-left only when actionable' "$VALIDATOR_MD"; then
  pass "(i) validator persona cites actionable-feedback rationale"
else
  err "(i) validator persona missing actionable-feedback rationale"
fi

if grep -qF 'sensor-cost-tiering.md' "$VALIDATOR_MD"; then
  pass "(i) validator persona references source PRD"
else
  err "(i) validator persona missing source PRD reference"
fi

# ---------------------------------------------------------------------
# (j) Templates persist schedule_next (progress.md + contracts.md)
# ---------------------------------------------------------------------
PROGRESS_TPL="$PLUGIN_ROOT/templates/progress.md"
CONTRACTS_TPL="$PLUGIN_ROOT/templates/contracts.md"

for tpl_pair in "progress.md:$PROGRESS_TPL" "contracts.md:$CONTRACTS_TPL"; do
  name="${tpl_pair%%:*}"
  path="${tpl_pair#*:}"
  if [ -f "$path" ]; then
    pass "(j) templates/${name} exists"
  else
    err "(j) templates/${name} is missing"
    continue
  fi
  if grep -qE '^[[:space:]]*-?[[:space:]]*schedule_next:' "$path"; then
    pass "(j) templates/${name} declares schedule_next:"
  else
    err "(j) templates/${name} missing schedule_next:"
  fi
  for key in 'sensors:' 'tiers:' 'reason:'; do
    if awk '
      /^[[:space:]]*-?[[:space:]]*schedule_next:/ { in_block = 1; next }
      in_block && /^[[:space:]]+-/ && !/^[[:space:]]+- timestamp:/ { in_block = 0 }
      in_block && /^[[:space:]]+(sensors|tiers|reason):/ { print }
    ' "$path" | grep -qF "$key"; then
      pass "(j) templates/${name} schedule_next block declares ${key}"
    else
      err "(j) templates/${name} schedule_next block missing ${key}"
    fi
  done
done

# ---------------------------------------------------------------------
# (k) Fixture verdict — schema check (valid + invalid cases)
# ---------------------------------------------------------------------
# A small inline schema validator for Validator verdicts. Required
# keys: schedule_next.sensors OR schedule_next.tiers (at least one
# non-empty) and schedule_next.reason (non-empty string).

verdict_well_formed() {
  local blob="$1"

  # Must have a schedule_next: section.
  printf '%s\n' "$blob" | grep -qE '^[[:space:]]*schedule_next:' || return 1

  # Extract the schedule_next sub-block (lines indented under it).
  local body
  body=$(printf '%s\n' "$blob" | awk '
    /^[[:space:]]*schedule_next:/ { in_block = 1; indent = -1; next }
    in_block {
      if (indent == -1) {
        match($0, /^[[:space:]]*/)
        indent = RLENGTH
        if (indent == 0) { exit }
      }
      # End block when indent shrinks below the block''s own indent
      match($0, /^[[:space:]]*/)
      if (RLENGTH < indent && $0 !~ /^[[:space:]]*$/) { exit }
      print
    }
  ')

  # `reason:` must be present and non-empty.
  local reason
  reason=$(printf '%s\n' "$body" | awk -F': ' '
    /^[[:space:]]+reason:/ {
      sub(/^[[:space:]]+reason:[[:space:]]*"?/, "", $0)
      sub(/"?[[:space:]]*$/, "", $0)
      print
      exit
    }
  ')
  [ -n "$reason" ] || return 1

  # Either sensors: or tiers: must be present and non-empty (i.e. not [] or empty).
  local sensors tiers
  sensors=$(printf '%s\n' "$body" | awk '
    /^[[:space:]]+sensors:/ {
      sub(/^[[:space:]]+sensors:[[:space:]]*/, "", $0)
      print
      exit
    }
  ')
  tiers=$(printf '%s\n' "$body" | awk '
    /^[[:space:]]+tiers:/ {
      sub(/^[[:space:]]+tiers:[[:space:]]*/, "", $0)
      print
      exit
    }
  ')

  local has_sensors=0
  local has_tiers=0
  if [ -n "$sensors" ] && [ "$sensors" != "[]" ]; then has_sensors=1; fi
  if [ -n "$tiers" ] && [ "$tiers" != "[]" ]; then has_tiers=1; fi

  if [ "$has_sensors" -eq 0 ] && [ "$has_tiers" -eq 0 ]; then
    return 1
  fi

  return 0
}

# Good fixture: tiers + reason citing a sensor id.
good_verdict='schedule_next:
  sensors: []
  tiers: ["cheap", "expensive"]
  reason: "linter-ruff and unit-pytest were green this cycle for Scenario 1; diff touches src/checkout.tsx covered by playwright-checkout"'

if verdict_well_formed "$good_verdict"; then
  pass "(k) well-formed verdict (tiers + reason) passes schema check"
else
  err "(k) well-formed verdict failed schema check"
fi

# Good fixture using sensors only (no tiers shorthand).
good_sensors_verdict='schedule_next:
  sensors: ["playwright-checkout"]
  tiers: []
  reason: "Scenario 1 diff touches checkout flow"'

if verdict_well_formed "$good_sensors_verdict"; then
  pass "(k) well-formed verdict (sensors only) passes schema check"
else
  err "(k) well-formed verdict (sensors only) failed schema check"
fi

# Bad fixture: missing schedule_next entirely.
no_block_verdict='criterion: "Scenario 1"
status: pass
sensor: linter-ruff'
if verdict_well_formed "$no_block_verdict"; then
  err "(k) verdict missing schedule_next was accepted (should fail)"
else
  pass "(k) verdict missing schedule_next is rejected"
fi

# Bad fixture: empty reason.
empty_reason_verdict='schedule_next:
  sensors: []
  tiers: ["cheap"]
  reason: ""'
if verdict_well_formed "$empty_reason_verdict"; then
  err "(k) verdict with empty reason was accepted (should fail)"
else
  pass "(k) verdict with empty reason is rejected"
fi

# Bad fixture: both sensors and tiers empty.
both_empty_verdict='schedule_next:
  sensors: []
  tiers: []
  reason: "doing nothing"'
if verdict_well_formed "$both_empty_verdict"; then
  err "(k) verdict with both sensors and tiers empty was accepted (should fail)"
else
  pass "(k) verdict with both sensors and tiers empty is rejected"
fi

# ---------------------------------------------------------------------
# (l) Pattern doc + SKILL.md describe Part 5 behavior
# ---------------------------------------------------------------------
SENSORS_PATTERN="$PLUGIN_ROOT/.vibeflow/patterns/sensors.md"
IMPLEMENT_SKILL="$PLUGIN_ROOT/skills/implement/SKILL.md"

if grep -qE '^### Cost tiering, sensor persistence, and Validator-owned scheduling' "$SENSORS_PATTERN"; then
  pass "(l) sensors.md adds 'Cost tiering, ... Validator-owned scheduling' subsection"
else
  err "(l) sensors.md missing Part-5 subsection"
fi

if grep -qE 'shift-left only when actionable|shift-feedback-left|actionable feedback' "$SENSORS_PATTERN"; then
  pass "(l) sensors.md cites actionable-feedback rationale"
else
  err "(l) sensors.md missing actionable-feedback rationale"
fi

if grep -qF 'Running all expensive sensors every cycle when the feature is mid-assembly' "$SENSORS_PATTERN"; then
  pass "(l) sensors.md adds anti-pattern entry for unconditional expensive runs"
else
  err "(l) sensors.md missing the new anti-pattern entry"
fi

if grep -qE 'Phase A.*cheap.*deterministic' "$IMPLEMENT_SKILL"; then
  pass "(l) implement SKILL.md describes Phase A (cheap)"
else
  err "(l) implement SKILL.md missing Phase A description"
fi

if grep -qE 'Phase B.*expensive.*gated' "$IMPLEMENT_SKILL"; then
  pass "(l) implement SKILL.md describes Phase B (expensive, gated)"
else
  err "(l) implement SKILL.md missing Phase B description"
fi

if grep -qF 'lib/sensors/append-runs.sh' "$IMPLEMENT_SKILL"; then
  pass "(l) implement SKILL.md invokes lib/sensors/append-runs.sh"
else
  err "(l) implement SKILL.md missing append-runs invocation"
fi

if grep -qE '\-\-tier all' "$IMPLEMENT_SKILL"; then
  pass "(l) implement SKILL.md merge-ready uses --tier all"
else
  err "(l) implement SKILL.md merge-ready missing --tier all"
fi

if grep -qE 'Cycle 1.*Phase A only|skip Phase B' "$IMPLEMENT_SKILL"; then
  pass "(l) implement SKILL.md documents cycle-1 Phase-A-only default"
else
  err "(l) implement SKILL.md missing cycle-1 default"
fi

# ---------------------------------------------------------------------
# (m) lib/sensors/append-runs.sh — unit tests
# ---------------------------------------------------------------------
APPEND_RUNS="$PLUGIN_ROOT/lib/sensors/append-runs.sh"

if [ -x "$APPEND_RUNS" ]; then
  pass "(m) lib/sensors/append-runs.sh exists and is executable"
else
  err "(m) lib/sensors/append-runs.sh missing or not executable"
fi

# Build a fresh fixture in its own tmpdir.
TMP_PART5=$(mktemp -d)
mkdir -p "$TMP_PART5/.yoke/sensors"
cat > "$TMP_PART5/.yoke/sensors/foo.md" <<'EOF'
---
id: foo
command: echo foo
class: computational
tier: cheap
applies_to: [some-task]
runs: []
---

# foo

## Caveats

## Calibration notes
EOF

# Append a single result via a hand-crafted snapshot.
cat > "$TMP_PART5/snapshot.yaml" <<'EOF'
results:
  - sensor: "foo"
    command: "echo foo"
    status: pass
    exit_code: 0
    output_excerpt: "foo passed cleanly"
    reason: ""
EOF

(cd "$TMP_PART5" && bash "$APPEND_RUNS" "$TMP_PART5/snapshot.yaml" 1 "Scenario 1" >/dev/null)

# Verify the runs: block now has one entry.
if grep -qE '^[[:space:]]*-[[:space:]]+\{cycle: 1' "$TMP_PART5/.yoke/sensors/foo.md"; then
  pass "(m) append-runs added cycle 1 entry to foo.md"
else
  err "(m) append-runs did not add a runs entry to foo.md"
fi

# Status field captured.
if grep -qE 'status: pass' "$TMP_PART5/.yoke/sensors/foo.md"; then
  pass "(m) append-runs entry includes status"
else
  err "(m) append-runs entry missing status"
fi

# Criterion captured.
if grep -qE 'criterion: "Scenario 1"' "$TMP_PART5/.yoke/sensors/foo.md"; then
  pass "(m) append-runs entry includes criterion"
else
  err "(m) append-runs entry missing criterion"
fi

# Body preserved.
if grep -qE '^# foo$' "$TMP_PART5/.yoke/sensors/foo.md"; then
  pass "(m) append-runs preserved body heading"
else
  err "(m) append-runs clobbered body"
fi

# Append 25 more cycles to test retention cap (N=20, cycles 2..26).
for n in $(seq 2 26); do
  cat > "$TMP_PART5/snapshot.yaml" <<EOF
results:
  - sensor: "foo"
    command: "echo foo"
    status: pass
    exit_code: 0
    output_excerpt: ""
    reason: ""
EOF
  (cd "$TMP_PART5" && bash "$APPEND_RUNS" "$TMP_PART5/snapshot.yaml" "$n" "Scenario 1" >/dev/null)
done

# After 26 appends total, only the last 20 should remain (cycles 7..26).
remaining_count=$(grep -cE '^[[:space:]]*-[[:space:]]+\{cycle: ' "$TMP_PART5/.yoke/sensors/foo.md")
if [ "$remaining_count" -eq 20 ]; then
  pass "(m) retention cap enforced (exactly 20 entries after 26 appends)"
else
  err "(m) retention cap broken — expected 20 entries, got ${remaining_count}"
fi

# Cycle 1 (first) should have rolled off.
if grep -qE '^[[:space:]]*-[[:space:]]+\{cycle: 1,' "$TMP_PART5/.yoke/sensors/foo.md"; then
  err "(m) oldest entry (cycle 1) was not rolled off"
else
  pass "(m) oldest entry (cycle 1) rolled off as expected"
fi

# Cycle 26 (newest) should be present.
if grep -qE '^[[:space:]]*-[[:space:]]+\{cycle: 26,' "$TMP_PART5/.yoke/sensors/foo.md"; then
  pass "(m) newest entry (cycle 26) present after retention"
else
  err "(m) newest entry missing"
fi

# Cycle 7 (boundary - oldest kept) should be present.
if grep -qE '^[[:space:]]*-[[:space:]]+\{cycle: 7,' "$TMP_PART5/.yoke/sensors/foo.md"; then
  pass "(m) boundary entry (cycle 7) present after retention"
else
  err "(m) boundary entry (cycle 7) missing"
fi

# Sensors without a file are skipped silently.
cat > "$TMP_PART5/snapshot.yaml" <<'EOF'
results:
  - sensor: "foo"
    command: "echo foo"
    status: pass
    exit_code: 0
    output_excerpt: ""
    reason: ""
  - sensor: "phantom"
    command: "echo phantom"
    status: pass
    exit_code: 0
    output_excerpt: ""
    reason: ""
EOF

set +e
(cd "$TMP_PART5" && bash "$APPEND_RUNS" "$TMP_PART5/snapshot.yaml" 99 "Scenario 1" >/dev/null 2>&1)
phantom_exit=$?
set -e

if [ "$phantom_exit" -eq 0 ]; then
  pass "(m) append-runs skips unregistered sensors silently (exit 0)"
else
  err "(m) append-runs failed when skipping unregistered sensor (exit ${phantom_exit})"
fi

if [ ! -f "$TMP_PART5/.yoke/sensors/phantom.md" ]; then
  pass "(m) append-runs did NOT create file for unregistered sensor"
else
  err "(m) append-runs created file for unregistered sensor (should skip)"
fi

# ---------------------------------------------------------------------
# (n) End-to-end smoke: cheap-only cycle leaves expensive untouched
# ---------------------------------------------------------------------
# Reuse the Part 2/3 fixture (TMP_PART2 has 4 sensors with files).

# Pre-state: capture mtimes of all sensor files.
declare -A pre_mtime
for id in linter-ruff unit-pytest judge-voice playwright-e2e; do
  pre_mtime["$id"]="$(stat -f '%m' "$TMP_PART2/.yoke/sensors/${id}.md" 2>/dev/null \
                   || stat -c '%Y' "$TMP_PART2/.yoke/sensors/${id}.md" 2>/dev/null)"
done

# Simulate Phase A only (cheap tier filter from Part 3).
phase_a_snapshot="$TMP_PART2/phase-a.yaml"
(cd "$TMP_PART2" && bash "$HOOK" --tier cheap --criterion 'Scenario 1' "$TMP_PART2/contract.md" 2>/dev/null > "$phase_a_snapshot")

# Append runs from the Phase A snapshot.
(cd "$TMP_PART2" && bash "$APPEND_RUNS" "$phase_a_snapshot" 1 "Scenario 1" >/dev/null)

# Cheap sensors (linter-ruff, unit-pytest) should have a runs entry.
for id in linter-ruff unit-pytest; do
  if grep -qE '^[[:space:]]*-[[:space:]]+\{cycle: 1' "$TMP_PART2/.yoke/sensors/${id}.md"; then
    pass "(n) end-to-end: cheap-tier sensor ${id} has cycle-1 runs entry"
  else
    err "(n) end-to-end: cheap-tier sensor ${id} missing cycle-1 entry"
  fi
done

# Expensive sensors (judge-voice, playwright-e2e) should NOT have a
# cycle-1 entry — they didn't run in Phase A. Their `runs:` from prior
# Part 4 fixture state may already have entries; we only assert no
# *cycle-1* entry was added for them.
for id in judge-voice playwright-e2e; do
  if grep -qE '^[[:space:]]*-[[:space:]]+\{cycle: 1' "$TMP_PART2/.yoke/sensors/${id}.md"; then
    err "(n) end-to-end: expensive sensor ${id} got cycle-1 entry (Phase B was skipped)"
  else
    pass "(n) end-to-end: expensive sensor ${id} unchanged when Phase B skipped"
  fi
done

# Now simulate Phase B authorization: run --tier expensive and append.
phase_b_snapshot="$TMP_PART2/phase-b.yaml"
(cd "$TMP_PART2" && bash "$HOOK" --tier expensive --criterion 'Scenario 1' "$TMP_PART2/contract.md" 2>/dev/null > "$phase_b_snapshot")
(cd "$TMP_PART2" && bash "$APPEND_RUNS" "$phase_b_snapshot" 2 "Scenario 1" >/dev/null)

# Now playwright-e2e (Scenario 1 expensive sensor) should have cycle-2.
if grep -qE '^[[:space:]]*-[[:space:]]+\{cycle: 2' "$TMP_PART2/.yoke/sensors/playwright-e2e.md"; then
  pass "(n) end-to-end: expensive sensor playwright-e2e has cycle-2 entry after Phase B"
else
  err "(n) end-to-end: playwright-e2e missing cycle-2 entry post-Phase-B"
fi

rm -rf "$TMP_PART5"

harness::summary
