#!/usr/bin/env bash
# tests/canonical-memory/canonize-progress-log-line.test.sh
#
# NOTE: A true end-to-end test for Acceptance Contract Scenario 4 —
# "/yoke:canonize from a fixture Yoke project with provider: bedrock
# dispatches to /bedrock:teach --working-memory <abs-path-to-.yoke>, exits
# 0, and appends a line beginning with `canonize:` to
# .yoke/runtime/progress.md" — requires invoking /yoke:canonize through
# Claude Code's Skill-tool dispatcher. That harness does not exist
# outside an interactive Claude Code session, and Sprint 01's coverage
# discipline (per the sprint file's "shape sensor" pattern — see
# canonize-skill-shape, search-canonical-memory-skill-shape,
# provider-contract-doc-shape) explicitly accepts a structural
# assertion in the test surface. Full E2E coverage:
#
#   - Sprint 02 sensor `end-to-end-implement-cycle` runs the full
#     ralph-loop and observes the canonize: line growth (Scenario 10 /
#     FR-5).
#   - Sprint 02 sensor `bedrock-canonize-roundtrip` exercises the
#     dispatch path through the extracted claude-bedrock peer plugin
#     and asserts the soft exit-summary regex (Scenario 9 / FR-4).
#
# What this test asserts (structural — necessary, not sufficient — for
# the runtime claim that the facade appends a canonize: line):
#
#   (1) skills/canonize/SKILL.md exists.
#   (2) Frontmatter declares `name: canonize` (Skill-tool dispatch
#       identity).
#   (3) Body sources `lib/canonical-memory/resolve-provider.sh`.
#   (4) Body dispatches via $YOKE_PROVIDER_CANONIZE_SKILL (no
#       hard-coded provider).
#   (5) Body resolves an absolute path for .yoke/ via `cd && pwd` and
#       passes it as `--working-memory <abs-path>` (Scenario 4 demand).
#   (6) Body documents the canonize:-line append to
#       .yoke/runtime/progress.md (the soft exit-summary convention
#       defined in docs/canonical-memory-provider-contract.md).
#   (7) The literal regex `^canonize:` (anchored at line start, with
#       the colon) appears in the body — providers and downstream
#       readers grep on this anchor per the contract.
#   (8) Body propagates the provider's exit code (Scenario 4: "exits 0,
#       propagates the provider's exit code").
#
# Sensor: canonize-progress-log-line (computational, cheap).

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

SKILL="$PLUGIN_ROOT/skills/canonize/SKILL.md"

# ----------------------------------------------------------------------
# (1) File presence.
# ----------------------------------------------------------------------
[ -f "$SKILL" ] && pass "(1) skills/canonize/SKILL.md exists" || {
  err "(1) skills/canonize/SKILL.md missing"
  harness::summary
}

# ----------------------------------------------------------------------
# (2) Frontmatter declares the dispatch identity.
# ----------------------------------------------------------------------
grep -q '^name: canonize$' "$SKILL" \
  && pass "(2) frontmatter: name == canonize" \
  || err "(2) frontmatter missing 'name: canonize'"

# ----------------------------------------------------------------------
# (3) Body sources the provider resolver.
# ----------------------------------------------------------------------
grep -q 'lib/canonical-memory/resolve-provider.sh' "$SKILL" \
  && pass "(3) body references lib/canonical-memory/resolve-provider.sh" \
  || err "(3) body does not source the provider resolver"

# ----------------------------------------------------------------------
# (4) Body dispatches via $YOKE_PROVIDER_CANONIZE_SKILL.
# ----------------------------------------------------------------------
grep -q 'YOKE_PROVIDER_CANONIZE_SKILL' "$SKILL" \
  && pass "(4) body dispatches via YOKE_PROVIDER_CANONIZE_SKILL (provider-agnostic)" \
  || err "(4) body does not reference YOKE_PROVIDER_CANONIZE_SKILL — dispatch may be hard-coded"

# ----------------------------------------------------------------------
# (5) Absolute-path resolution + --working-memory argument shape.
# ----------------------------------------------------------------------
grep -qE 'cd[[:space:]]+"?\$PWD/\.yoke"?[[:space:]]*&&[[:space:]]*pwd' "$SKILL" \
  && pass "(5a) body resolves .yoke/ to an absolute path via cd && pwd" \
  || err "(5a) body does not show the absolute-path resolution idiom (cd \"\$PWD/.yoke\" && pwd)"

grep -q -- '--working-memory' "$SKILL" \
  && pass "(5b) body passes --working-memory <abs-path> to the provider's canonize skill" \
  || err "(5b) body does not pass --working-memory to the provider's canonize skill"

# ----------------------------------------------------------------------
# (6) Append a canonize: line to .yoke/runtime/progress.md.
# Two structural signals:
#   - the body references runtime/progress.md as the append target;
#   - the body shows an append (>>) of a canonize-prefixed line.
# ----------------------------------------------------------------------
grep -q 'runtime/progress.md' "$SKILL" \
  && pass "(6a) body references runtime/progress.md as the append target" \
  || err "(6a) body does not reference runtime/progress.md"

grep -qE '>>[[:space:]]*"?\$progress"?' "$SKILL" \
  && pass "(6b) body appends (>>) to the progress file" \
  || err "(6b) body does not show an append (>>) to the progress file"

# ----------------------------------------------------------------------
# (7) The contract regex `^canonize:` is documented in the body
# (downstream readers grep on this anchor per the working-memory
# provider contract).
# ----------------------------------------------------------------------
grep -qE "'\^canonize:'|\"\\\^canonize:\"|\\^canonize:" "$SKILL" \
  && pass "(7) body documents the '^canonize:' line-anchor regex" \
  || err "(7) body does not document the '^canonize:' line-anchor regex"

# ----------------------------------------------------------------------
# (8) Body propagates the provider's exit code.
# ----------------------------------------------------------------------
grep -qE '(exit[[:space:]]+"?\$provider_rc"?|propagate.*exit code)' "$SKILL" \
  && pass "(8) body propagates the provider's exit code" \
  || err "(8) body does not propagate the provider's exit code"

harness::summary
