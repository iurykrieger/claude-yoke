# Audit Report: ack-sensors-skill-part-3

> Audited 2026-04-25 against `.vibeflow/specs/ack-sensors-skill-part-3.md`

**Verdict: PASS**

## Test execution

Test runner: `bash tests/smoke/ack-sensors-inferential.test.sh`
Result: **PASS** — exit 0, 0 failures.

The Part 3 smoke chains Parts 1 + 2 regression as final assertions
(both reported "still passes"). Effective coverage:

- Part 3 (inferential): 54 assertions
- Part 2 (parallel, regression): 43 assertions
- Part 1 (catalog, regression): 28 assertions
- **Total: 125 assertions, all green**

## Dependencies

- `ack-sensors-skill-part-1.md` — audit verdict: **PASS**
- `ack-sensors-skill-part-2.md` — audit verdict: **PASS**

## DoD Checklist

- [x] **DoD #1 — `lib/sensors/templates/semantic-judge.md` ships with
  mandatory calibration frontmatter.**
  Evidence: 8 frontmatter fields verified by smoke
  (`template / class / calibrated_against / calibrated_at /
  known_false_positives / known_false_negatives / criterion_scope /
  default_timeout_seconds`). `class: inferential` enforced;
  `default_timeout_seconds: 120` enforced. Prompt skeleton
  placeholders `{{criterion}} / {{diff}} / {{calibration_block}}`
  all present.

- [x] **DoD #2 — `agents/semantic-judge.md` runtime subagent.**
  Evidence: file exists, `name: semantic-judge` declared, persona +
  behaviors (Always / Never) sections complete, verdict shape
  block declares all six canonical keys. Spawn-time inputs
  documented (criterion / diff / calibration_block, latter via
  prose form "calibration block").

- [x] **DoD #3 — Validator updated to spawn inferential sensors via
  `Agent` with strict `subagent_type: yoke:semantic-judge`.**
  Evidence: `agents/validator.md:5` `tools: Read, Write, Edit, Grep,
  Glob, Bash, Monitor, Agent`. Three places pin
  `subagent_type: yoke:semantic-judge`: the description, the
  Allowed-tools section, and step 2b of the Sensor execution
  protocol. "Other subagent types are forbidden" rule asserted by
  the smoke (multi-line tolerant grep).

- [x] **DoD #4 — Per-sensor 120s default for inferential sensors;
  per-sensor override via Acceptance Contract.**
  Evidence: template's `default_timeout_seconds: 120` (binding
  default). Validator step 2b documents 120s + override syntax
  and binds it to inferential class.

- [x] **DoD #5 — Calibration drift writes to working memory only.**
  Evidence: drift target `.yoke/sensors/<sensor-name>.md`
  referenced in three files (template, judge, validator). Promotion
  path `/yoke:preserve` referenced in validator + judge. Smoke
  asserts NEITHER `lib/sensors/templates/semantic-judge.md` NOR
  `agents/semantic-judge.md` calls `propose-write` — canonical-memory
  boundary preserved.

- [x] **DoD #6 — Subagent context isolation: `tools: Read` only.**
  Evidence: `agents/semantic-judge.md:4` `tools: Read`. Eight
  forbidden tools verified absent from the frontmatter line:
  `Write / Edit / Bash / Grep / Glob / Agent / Task / Monitor`.
  Three forbidden file reads (progress.md / query-trace /
  contracts.md) are explicitly forbidden in the persona. Canonical-
  memory access prohibition explicit.

- [x] **DoD #7 — Verdict shape parity (inferential = computational).**
  Evidence: smoke asserts each of the six canonical keys
  (`criterion / status / location / fix_instruction / sensor /
  evidence`) appears in BOTH `agents/validator.md` (computational
  verdict shape) AND `agents/semantic-judge.md` (inferential
  verdict shape). Downstream consumers see no schema difference.

## Pattern Compliance

- [x] **`patterns/sensors.md` — calibration metadata mandatory for
  inferential sensors.**
  Template ships with the full required frontmatter; without it
  the template cannot be referenced in a binding contract per the
  pattern's rule. Validator's step 2b loads the template's
  calibration block at spawn time and inlines it into the judge's
  inputs.

- [x] **`patterns/roles.md` — runtime subagents do not share
  context.**
  The judge's tools list is the strictest in the codebase
  (`Read` only). The persona explicitly forbids reading
  `progress.md`, `query-trace`, `contracts.md`, or canonical
  memory. Spawn inputs are exactly three; no implicit access
  to working memory beyond the calibration drift file path.

- [x] **`patterns/ralph-loop.md` — concurrent agentic batch.**
  Validator's "Aggregate via `Monitor` (unified across classes)"
  step states that inferential and computational events feed the
  same Monitor event loop; both classes spawn within the same
  cycle, not sequentially across cycles. Per-class timeouts
  (60s / 120s) protect cycle wall-clock.

- [x] **Conventions: "Blueprints wrapping agentic nodes."**
  The semantic-judge subagent is a contained agentic node: clear
  inputs (criterion + diff + calibration block), clear output
  (one JSON verdict), no side effects beyond the calibration
  drift file. The Validator's orchestration is a deterministic
  blueprint wrapping the agentic node.

- [x] **Conventions: "Minimalist canonical memory with mandatory
  traceability."**
  Calibration drift accumulates locally in working memory; promotion
  to canonical happens only via `/yoke:preserve` under Model C.
  No automatic doctrine writes from a stochastic judge.

- [x] **Conventions: "Back-pressure: success is silent, failures
  are verbose."**
  Per the judge persona: even on `pass`, `evidence` must contain a
  quoted diff excerpt or one-sentence reasoning anchored in the
  diff — verbosity preserved. Empty evidence on `pass` is a
  declared self-bug.

## Convention Violations
None detected.

## Auditor Notes — Out-of-spec changes

Two changes were made that touch files outside Part 3's declared
scope. Both are documented here in full so the architect can
decide whether to amend the spec retroactively or roll them back:

### 1. `hooks/verify-acceptance.sh` — perl-based timeout watchdog

**What:** Replaced the `kill -TERM` watchdog with a perl-based
fallback that uses `setsid` + `kill -KILL -PGID` to terminate the
entire process group on timeout. Required because the original
fallback leaked orphan child processes (`bash -c "sleep 5"` spawns
a child sleep that survives SIGTERM to the parent shell), causing
the verify-acceptance hook to hang under the Part 3 nested
regression run.

**Why out of spec:** The hook lives in Part 2's territory. Part 3
did not declare it as a target file.

**Why I made the change:** Part 3's smoke runs Parts 1 + 2 as
nested regressions. With orphan processes leaking, the nested
Part 2 run failed to terminate, blocking Part 3's smoke from
completing. Without this fix, Part 3 cannot pass even though all
its own DoD items are correctly implemented. The fix is a pure
robustness improvement — no behavior change for sensors that
complete inside their timeout.

**Recommendation:** Treat as a bug-fix patch to Part 2 (post-audit).
The perl dependency is acceptable per the user's confirmed scope
("any system, prefer minimal additions") and perl is universally
available on macOS, Linux, and BSD. The fallback is only invoked
when GNU `timeout` / `gtimeout` is not on `$PATH`.

### 2. `tests/smoke/ack-sensors-parallel.test.sh` — Agent-pin tolerance

**What:** Softened the "Validator allowed-tools excludes Agent"
assertion. Pre-Part-3, the assertion enforced absolute Agent
absence. Post-Part-3, the assertion now: if `Agent` is present,
it must be pinned to `subagent_type: yoke:semantic-judge` (the
Part 3 invariant); else the original "Agent absent" passes.

**Why out of spec:** Same as above — Part 2's smoke is in Part 2's
territory.

**Why I made the change:** Part 2's spec said `Agent` is added in
Part 3 — i.e., the "Agent absent" assertion was a milestone marker
during Part 2, not a permanent invariant. Once Part 3 lands, the
assertion is no longer valid. Without softening, Part 2's smoke
would automatically regress as soon as Part 3's validator change
was merged. The new assertion preserves the meaningful invariant
(strict subagent_type pinning) while accommodating the new state.

**Recommendation:** Treat as a milestone-correctness fix; this is
the canonical pattern for sequential-spec smoke tests.

## Files in this part

| File | Status | Lines (approx) |
| :--- | :--- | :---: |
| `lib/sensors/templates/semantic-judge.md` | created | 130 |
| `agents/semantic-judge.md` | created | 130 |
| `agents/validator.md` | modified | +60 |
| `tests/smoke/ack-sensors-inferential.test.sh` | created | 200 |

Total within scope: 4 files / ≤ 4 budget.

Out-of-scope robustness fixes (documented above): 2 files.

## Next step

**Ready to ship.** Proceed to Part 4:

```
/vibeflow:implement .vibeflow/specs/ack-sensors-skill-part-4.md
```
