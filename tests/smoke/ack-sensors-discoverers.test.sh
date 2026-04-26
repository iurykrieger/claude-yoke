#!/bin/bash
# tests/smoke/ack-sensors-discoverers.test.sh
#
# Part 4 smoke test for additional discoverers (package.json, Makefile,
# pyproject.toml) + unified catalog union/dedup. Validates DoD #1–#7
# from .vibeflow/specs/ack-sensors-skill-part-4.md:
#   - per-discoverer classification + emission
#   - best-effort posture (broken/missing → sensors: [] + notes:)
#   - unified catalog deduplicates by (category, command), keeps
#     first-seen, and remains deterministic
#   - no new external dependencies (no jq / python in scripts)

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACK="${PLUGIN_ROOT}/lib/sensors/ack-sensors.sh"
D_PKG="${PLUGIN_ROOT}/lib/sensors/discover-from-package-json.sh"
D_MAKE="${PLUGIN_ROOT}/lib/sensors/discover-from-makefile.sh"
D_PYP="${PLUGIN_ROOT}/lib/sensors/discover-from-pyproject.sh"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- ack-sensors Part 4 smoke ---"

[ -x "$D_PKG"  ] || { err "missing executable: $D_PKG";  exit 1; }
[ -x "$D_MAKE" ] || { err "missing executable: $D_MAKE"; exit 1; }
[ -x "$D_PYP"  ] || { err "missing executable: $D_PYP";  exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------------------
# DoD #1 — package.json discoverer: classification + emission
# ---------------------------------------------------------------------------
pkg_dir="${tmp}/with-package-json"
mkdir -p "$pkg_dir"
cat > "${pkg_dir}/package.json" <<'EOF'
{
  "name": "demo",
  "scripts": {
    "test": "jest",
    "lint": "eslint .",
    "build": "vite build",
    "e2e": "playwright test",
    "dev": "vite",
    "format": "prettier --write ."
  }
}
EOF

pkg_out="$(bash "$D_PKG" "${pkg_dir}/package.json")"
echo "$pkg_out" | grep -q 'category: testing' && pass "package-json classifies test → testing" || err "package-json: test not classified as testing"
echo "$pkg_out" | grep -q 'category: linting' && pass "package-json classifies lint → linting" || err "package-json: lint not classified as linting"
echo "$pkg_out" | grep -q 'category: build'   && pass "package-json classifies build → build" || err "package-json: build not classified as build"
echo "$pkg_out" | grep -q '"npm run test"'    && pass "package-json command is 'npm run test'" || err "package-json command not formed correctly"
# `dev` and `format` go to `other` (not in classified prefix list)
echo "$pkg_out" | grep -q 'category: other'   && pass "package-json surfaces other category for unclassified scripts" || err "package-json missing 'other' category"
echo "$pkg_out" | grep -q 'source: package-json' && pass "package-json sets source: package-json" || err "package-json wrong source"

# DoD #6 — best-effort posture: missing file → empty
missing_out="$(bash "$D_PKG" "/nonexistent/package.json")"
[ "$?" -eq 0 ] || err "package-json discoverer non-zero on missing file"
echo "$missing_out" | grep -q '^sensors: \[\]' && pass "package-json missing → sensors: []" || err "package-json missing did not produce empty sensors:"
echo "$missing_out" | grep -q '^notes:'        && pass "package-json missing → notes: present" || err "package-json missing missing notes:"

# DoD #6 — broken JSON (no scripts block) → empty + notes
broken_pkg="${tmp}/broken-package.json"
echo "{}" > "$broken_pkg"
broken_out="$(bash "$D_PKG" "$broken_pkg")"
echo "$broken_out" | grep -q '^sensors: \[\]' && pass "package-json no-scripts → sensors: []" || err "package-json no-scripts did not return empty"

# ---------------------------------------------------------------------------
# DoD #2 — Makefile discoverer: classification + skip rule bodies
# ---------------------------------------------------------------------------
mk_dir="${tmp}/with-makefile"
mkdir -p "$mk_dir"
cat > "${mk_dir}/Makefile" <<'EOF'
.PHONY: test lint build clean

test:
	pytest tests/

lint:
	ruff check .

build:
	go build ./...

clean:
	echo "key: value"
	rm -rf dist/

deploy: build
	./scripts/deploy.sh
EOF

mk_out="$(bash "$D_MAKE" "${mk_dir}/Makefile")"
echo "$mk_out" | grep -q '"make test"'  && pass "makefile finds 'test' target → 'make test'" || err "makefile missing 'make test'"
echo "$mk_out" | grep -q '"make lint"'  && pass "makefile finds 'lint' target → 'make lint'" || err "makefile missing 'make lint'"
echo "$mk_out" | grep -q '"make build"' && pass "makefile finds 'build' target → 'make build'" || err "makefile missing 'make build'"
echo "$mk_out" | grep -q '"make deploy"' && pass "makefile finds 'deploy' target (with prereq) → 'make deploy'" || err "makefile missing 'make deploy'"
echo "$mk_out" | grep -q 'source: makefile' && pass "makefile sets source: makefile" || err "makefile wrong source"

# DoD #6 — confirm rule body's `echo "key: value"` did NOT pollute targets.
# Match `echo` as either a `command:` value or a target name.
if echo "$mk_out" | grep -qE '"make echo"|category: [a-z]+\n[[:space:]]+command: "make echo"'; then
  err "makefile parser misidentified rule body as a target"
else
  pass "makefile parser ignores rule body (echo \"key: value\" not a target)"
fi
# `.PHONY` must not appear as a target either
if echo "$mk_out" | grep -q '"make .PHONY"'; then
  err "makefile parser surfaced .PHONY as target"
else
  pass "makefile parser excludes .PHONY"
fi

# ---------------------------------------------------------------------------
# DoD #3 — pyproject.toml discoverer: section recognition
# ---------------------------------------------------------------------------
pyp_dir="${tmp}/with-pyproject"
mkdir -p "$pyp_dir"
cat > "${pyp_dir}/pyproject.toml" <<'EOF'
[project]
name = "demo"

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.ruff]
line-length = 88

[tool.ruff.lint]
select = ["E", "F"]

[tool.mypy]
strict = true

[tool.poetry.scripts]
mycli = "demo.main:cli"
EOF

pyp_out="$(bash "$D_PYP" "${pyp_dir}/pyproject.toml")"
echo "$pyp_out" | grep -q '"pytest"'      && pass "pyproject finds [tool.pytest.ini_options] → pytest" || err "pyproject missing pytest"
echo "$pyp_out" | grep -q '"ruff check"'  && pass "pyproject finds [tool.ruff] → 'ruff check'" || err "pyproject missing ruff check"
echo "$pyp_out" | grep -q '"mypy"'        && pass "pyproject finds [tool.mypy] → mypy" || err "pyproject missing mypy"
echo "$pyp_out" | grep -q 'source: pyproject' && pass "pyproject sets source: pyproject" || err "pyproject wrong source"
# Ruff sub-section [tool.ruff.lint] should NOT produce a duplicate ruff command
ruff_count=$(echo "$pyp_out" | grep -c '"ruff check"' || true)
if [ "$ruff_count" -eq 1 ]; then
  pass "pyproject does not duplicate ruff command for sub-sections"
else
  err "pyproject emitted $ruff_count ruff commands (expected 1)"
fi

# DoD #6 — broken/empty pyproject → empty + notes
empty_pyp="${tmp}/empty-pyproject.toml"
echo "" > "$empty_pyp"
empty_pyp_out="$(bash "$D_PYP" "$empty_pyp")"
echo "$empty_pyp_out" | grep -q '^sensors: \[\]' && pass "pyproject empty → sensors: []" || err "pyproject empty did not produce empty"

# Inline-table warning
inline_pyp="${tmp}/inline-pyproject.toml"
cat > "$inline_pyp" <<'EOF'
tool.ruff = { line-length = 88 }
EOF
inline_out="$(bash "$D_PYP" "$inline_pyp")"
echo "$inline_out" | grep -qiE 'inline.table' && pass "pyproject warns on inline-table tool sections" || err "pyproject did not warn on inline tables"

# ---------------------------------------------------------------------------
# DoD #4 — unified catalog: union + dedup + deterministic
# ---------------------------------------------------------------------------
unified_dir="${tmp}/unified"
mkdir -p "$unified_dir"
cat > "${unified_dir}/CLAUDE.md" <<'EOF'
# Unified

## Testing
- `npm test` — unit tests
- `pytest` — python tests

## Linting
- `npm run lint` — eslint
EOF
cat > "${unified_dir}/package.json" <<'EOF'
{
  "scripts": {
    "test": "jest",
    "lint": "eslint .",
    "build": "vite build"
  }
}
EOF
cat > "${unified_dir}/Makefile" <<'EOF'
test:
	pytest

lint:
	ruff check .
EOF
cat > "${unified_dir}/pyproject.toml" <<'EOF'
[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.mypy]
strict = true
EOF

unified_a="$(cd "$unified_dir" && bash "$ACK")"
unified_b="$(cd "$unified_dir" && bash "$ACK")"

if [ "$unified_a" = "$unified_b" ]; then
  pass "unified catalog is deterministic across invocations"
else
  err "unified catalog non-deterministic"
fi

# Dedup: CLAUDE.md `npm run lint` (linting) and package-json `npm run lint`
# (linting) are the same (category, command). The result should keep the
# CLAUDE.md-source entry (first-seen via discoverer ordering).
lint_npm_count=$(echo "$unified_a" | awk '
  /^  - category: linting$/ { in_e=1; next }
  in_e && /^    command: "npm run lint"$/ { matched=1 }
  in_e && /^    source:/ { if (matched) print; matched=0; in_e=0 }
')
n_lint_npm=$(echo "$lint_npm_count" | grep -c 'source:' || true)
if [ "$n_lint_npm" -eq 1 ]; then
  pass "dedup: 'npm run lint' (linting) appears exactly once"
else
  err "dedup: 'npm run lint' (linting) appears $n_lint_npm times (expected 1)"
fi
# And the surviving entry's source should be claude-md (first-seen wins)
if echo "$unified_a" | awk '
    /^  - category: linting$/ { in_e=1; next }
    in_e && /^    command: "npm run lint"$/ { matched=1; next }
    in_e && /^    source:/ { print; in_e=0; matched=0 }
  ' | grep -q 'source: claude-md'; then
  pass "dedup: claude-md wins over package-json for the same (category, command)"
else
  err "dedup: claude-md did not win first-seen for npm run lint"
fi

# Same-command different category should NOT dedup (e.g. testing pytest from
# CLAUDE.md and pyproject — same command, same category → DEDUP).
pytest_count=$(echo "$unified_a" | awk '
  /^  - category: testing$/ { in_e=1; next }
  in_e && /^    command: "pytest"$/ { matched=1 }
  in_e && /^    source:/ { if (matched) print; matched=0; in_e=0 }
' | grep -c 'source:' || true)
if [ "$pytest_count" -eq 1 ]; then
  pass "dedup: 'pytest' (testing) appears exactly once across CLAUDE.md+pyproject"
else
  err "dedup: 'pytest' appears $pytest_count times (expected 1)"
fi

# Sort order assertion: every category's entries must be sorted by source then command.
# Pull just the category/source pairs.
sort_check="$(echo "$unified_a" | awk '
  /^  - category:/ { sub(/^  - category: */, "", $0); cat=$0; next }
  /^    source:/   { sub(/^    source: */, "", $0); print cat "\t" $0 }
')"
sorted="$(printf '%s\n' "$sort_check" | LC_ALL=C sort)"
if [ "$sort_check" = "$sorted" ]; then
  pass "unified catalog rows sorted by (category, source) under LC_ALL=C"
else
  err "unified catalog not sorted by (category, source)"
fi

# ---------------------------------------------------------------------------
# DoD #5 — Smoke covers all four sources via the unified test fixture
# (already exercised above). Confirm catalog mode emits at least one
# entry for each source.
# ---------------------------------------------------------------------------
for src in claude-md makefile package-json pyproject; do
  if echo "$unified_a" | grep -q "source: ${src}"; then
    pass "unified catalog includes source: ${src}"
  else
    err "unified catalog missing source: ${src}"
  fi
done

# ---------------------------------------------------------------------------
# DoD #7 — No new external dependencies (no jq / python / etc.)
# ---------------------------------------------------------------------------
for f in "$D_PKG" "$D_MAKE" "$D_PYP"; do
  # Strip comments and the shebang before the runtime check — the
  # script's prose may legitimately mention "no jq, no Python" in a
  # banner comment. We only flag actual command invocations.
  body="$(awk '/^#/ { next } { print }' "$f")"
  if printf '%s' "$body" | grep -qE '(^|[[:space:]])(jq|python|python3|node|ruby|perl)([[:space:]]|$)'; then
    err "discoverer $(basename "$f") invokes an external runtime (jq/python/node/...)"
  else
    pass "discoverer $(basename "$f") uses only bash + POSIX awk"
  fi
done

# ---------------------------------------------------------------------------
# Regression — Parts 1, 2, 3 still pass
# ---------------------------------------------------------------------------
if bash "${PLUGIN_ROOT}/tests/smoke/ack-sensors-catalog.test.sh" >/dev/null 2>&1; then
  pass "Part 1 catalog smoke still passes"
else
  err "Part 1 catalog smoke regressed!"
fi

if bash "${PLUGIN_ROOT}/tests/smoke/ack-sensors-parallel.test.sh" >/dev/null 2>&1; then
  pass "Part 2 parallel smoke still passes"
else
  err "Part 2 parallel smoke regressed!"
fi

if bash "${PLUGIN_ROOT}/tests/smoke/ack-sensors-inferential.test.sh" >/dev/null 2>&1; then
  pass "Part 3 inferential smoke still passes"
else
  err "Part 3 inferential smoke regressed!"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "--- ack-sensors Part 4 smoke: ${fail} failure(s) ---"
exit "$fail"
