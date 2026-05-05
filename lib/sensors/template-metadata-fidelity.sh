#!/bin/bash
# Sensor: template-metadata-fidelity
# Pins the producer/trigger lines of every producer-owned template
# against the actual producer skill that owns the template.
#
# Mirrors the structural pure-bash sensor pattern documented in
# concepts/yoke-decision-2026-04-27-bidirectional-invariant-sensor-pattern
# (canonical memory) — sibling to lib/sensors/no-vibeflow-refs.sh in
# discipline (silent success, structured-YAML stderr on failure,
# allowlist construction at top of file, needle constructed at runtime
# to avoid the self-reference paradox).
#
# Five violation classes are emitted:
#   - producer-mismatch        — opening or closing blockquote does not
#                                cite the allowlist's producer slash command
#   - trigger-mismatch         — opening or closing blockquote does not
#                                cite the allowlist's trigger name
#   - producer-skill-missing   — the allowlist names a skill SKILL.md
#                                that does not exist on disk (stale entry)
#   - template-missing         — the allowlist names a template that
#                                does not exist on disk (stale entry)
#   - legacy-string-leaked     — the literal "Trigger 2 approves" phrase
#                                appears outside a carve-out paragraph
#
# Carve-out paragraphs (blockquote paragraphs containing
# legacy-flow|pre-cutover|legacy producer) are exempt from the
# attribution checks — they are historical statements about pre-cutover
# templates, not current attribution claims.
#
# Exit 0 silent on success; exit 1 with structured YAML violation blocks
# on stderr otherwise. Self-reference paradox: the legacy needle
# "Trigger 2"" approves" is constructed by string concatenation at
# runtime so that this script's source and its self-test never trip
# their own checks.
#
# Source: .yoke/acceptance-criteria/2026-05-05-template-attribution-drift.md
# US-003 + AC-003-* / FR-7 of fix-spec
# .yoke/fixes/2026-05-05-template-attribution-drift.md.

set -euo pipefail

# Allowlist of producer-owned templates: pipe-separated tuple of
# (template path, producer SKILL.md path, trigger name, producer slash command).
# Future producer-owned templates extend this array.
TEMPLATES=(
  "templates/sprint.md|skills/generate-sprints/SKILL.md|Trigger 2.5|/yoke:generate-sprints"
)

CARVEOUT_RE='legacy-flow|pre-cutover|legacy producer'

# Self-reference paradox: build the legacy needle by concatenation so
# this script can describe what it searches for without tripping its
# own check on a future scan that might cover lib/sensors/.
legacy_needle_left="Trigger 2"
legacy_needle_right=" approves"
legacy_needle="${legacy_needle_left}${legacy_needle_right}"

# Validate every allowlist entry's boundary conditions (template +
# producer-skill existence). Any violation here is a stale-allowlist
# signal and exits non-zero before per-template attribution checks.
violations=0

for entry in "${TEMPLATES[@]}"; do
  IFS='|' read -r template skill trigger producer_cmd <<<"$entry"

  if [[ ! -f "$template" ]]; then
    cat >&2 <<EOF
- id: template-metadata-fidelity:${template}:template-missing
  location: ${template}:0
  correction_instruction: "Remove or correct the allowlist entry for '${template}' in lib/sensors/template-metadata-fidelity.sh; the file does not exist."
  reference: "[[yoke-pattern-sensors]]"
EOF
    violations=$((violations + 1))
    continue
  fi

  if [[ ! -f "$skill" ]]; then
    cat >&2 <<EOF
- id: template-metadata-fidelity:${template}:producer-skill-missing
  location: ${skill}:0
  correction_instruction: "Restore '${skill}' or update the allowlist entry for '${template}' in lib/sensors/template-metadata-fidelity.sh."
  reference: "[[yoke-pattern-sensors]]"
EOF
    violations=$((violations + 1))
    continue
  fi

  # Per-template attribution check via Python (clean blockquote
  # paragraph parsing). The Python step emits zero or more YAML
  # violation blocks on stderr and exits 0 on no findings, 1 on
  # findings, 2 on structural anomalies.
  py_rc=0
  python3 - "$template" "$producer_cmd" "$trigger" "$CARVEOUT_RE" "$legacy_needle" <<'PY' || py_rc=$?
import sys
import re

path, producer, trigger, carveout_re, legacy_needle = sys.argv[1:6]

with open(path, encoding="utf-8") as fh:
    lines = fh.readlines()

# Find first H1.
h1_idx = next((i for i, line in enumerate(lines) if line.startswith("# ")), None)
if h1_idx is None:
    print(
        f'- id: template-metadata-fidelity:{path}:no-h1\n'
        f'  location: {path}:1\n'
        f'  correction_instruction: '
        f'"Add an H1 heading to {path}; the sensor anchors the opening blockquote on the first H1."\n'
        f'  reference: "[[yoke-pattern-sensors]]"',
        file=sys.stderr,
    )
    sys.exit(1)

# Walk every blockquote paragraph after the first H1.
# A paragraph is a contiguous run of lines whose first non-whitespace
# character is '>'.
paragraphs = []  # (start_line, end_line_exclusive, body_text, is_carveout)
i = h1_idx + 1
n = len(lines)
while i < n:
    if re.match(r'^\s*>', lines[i]):
        start = i
        while i < n and re.match(r'^\s*>', lines[i]):
            i += 1
        end = i  # exclusive
        body = "".join(lines[start:end])
        is_carveout = bool(re.search(carveout_re, body))
        paragraphs.append((start + 1, end + 1, body, is_carveout))
    else:
        i += 1

non_carveout = [p for p in paragraphs if not p[3]]

violations = []

if len(non_carveout) < 2:
    violations.append(
        (
            "insufficient-attribution-blockquotes",
            f"{path}:1",
            f"'{path}' must carry at least two non-carve-out blockquotes "
            f"(opening + closing trailer); found {len(non_carveout)}.",
        )
    )
else:
    opening = non_carveout[0]
    closing = non_carveout[-1]

    if producer not in opening[2]:
        violations.append(
            (
                "producer-mismatch",
                f"{path}:{opening[0]}-{opening[1] - 1}",
                f"Update '{path}' opening blockquote to cite '{producer}' "
                f"(the actual producer skill).",
            )
        )
    if trigger not in opening[2]:
        violations.append(
            (
                "trigger-mismatch",
                f"{path}:{opening[0]}-{opening[1] - 1}",
                f"Update '{path}' opening blockquote to cite '{trigger}' "
                f"(the actual ratifying gate).",
            )
        )
    if producer not in closing[2]:
        violations.append(
            (
                "producer-mismatch",
                f"{path}:{closing[0]}-{closing[1] - 1}",
                f"Update '{path}' closing trailer to cite '{producer}' "
                f"(the actual producer skill).",
            )
        )
    if trigger not in closing[2]:
        violations.append(
            (
                "trigger-mismatch",
                f"{path}:{closing[0]}-{closing[1] - 1}",
                f"Update '{path}' closing trailer to cite '{trigger}' "
                f"(the actual ratifying gate).",
            )
        )

# legacy-string-leaked: scan every line for the legacy needle; any
# match outside a carve-out paragraph is a violation.
for line_no, line in enumerate(lines, start=1):
    if legacy_needle not in line:
        continue
    in_carveout = any(
        start <= line_no < end and is_carveout
        for (start, end, _body, is_carveout) in paragraphs
    )
    if not in_carveout:
        violations.append(
            (
                "legacy-string-leaked",
                f"{path}:{line_no}",
                f"Remove the legacy '{legacy_needle}' phrase at {path}:{line_no} — "
                f"it survived the Phase-2.5 cutover.",
            )
        )

for klass, location, fix in violations:
    print(
        f"- id: template-metadata-fidelity:{path}:{klass}\n"
        f"  location: {location}\n"
        f'  correction_instruction: "{fix}"\n'
        f'  reference: "[[yoke-pattern-sensors]]"',
        file=sys.stderr,
    )

sys.exit(1 if violations else 0)
PY

  if [[ $py_rc -ne 0 ]]; then
    violations=$((violations + 1))
  fi
done

if [[ $violations -gt 0 ]]; then
  echo "sensor: template-metadata-fidelity found ${violations} violation(s)" >&2
  exit 1
fi

exit 0
