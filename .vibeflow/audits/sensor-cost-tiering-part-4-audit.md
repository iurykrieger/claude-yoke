# Audit Report: sensor-cost-tiering — Part 4 (Validator scheduling)

> Audited on 2026-04-27
> Spec: `.vibeflow/specs/sensor-cost-tiering-part-4.md`
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`
> Depends on: Parts 1 (PASS) and 2 (PASS)

**Verdict: PASS**

## Test execution

- Commands: `bash tests/sensor-tiering.test.sh`; `bash tests/run-all.sh`.
- Result: **PASS** — 86/86 assertions in `sensor-tiering.test.sh` (28
  new in (i)+(j)+(k)); **19/19 test files PASS** in the full suite
  (zero regressions).

## DoD Checklist

- [x] **DoD 1 — Validator reads `.yoke/sensors/<id>.md`.** Persona's
  Memory scope and Always section both reference the per-sensor file
  as a read source for `schedule_next` reasoning. Read is scoped to
  sensors mapped to targeted criterion(s).
  *Evidence:* `agents/validator.md` Memory scope + Always entry; test
  "(i) validator persona references .yoke/sensors/<id>.md as a read"
  — PASS.

- [x] **DoD 2 — `schedule_next:` shape required.** Locked to
  `{sensors: [...], tiers: [cheap|expensive], reason: "..."}`. Schema
  documented in persona's Always section; at least one of `sensors:`
  or `tiers:` must be non-empty.
  *Evidence:* `agents/validator.md`; tests "(i) validator schedule_next
  schema declares sensors:/tiers:/reason:" — 3 PASS.

- [x] **DoD 3 — Default rule documented.** "Always include
  `tier:cheap`"; "Include `tier:expensive` when cheap-tier was green
  for the targeted criterion(s) on the previous cycle, OR diff
  touches expensive-relevant surface, OR merge-ready check".
  *Evidence:* tests "(i) validator persona documents 'cheap always'
  default rule" + "... 'expensive when cheap-green' rule" — PASS.

- [x] **DoD 4 — Cycle-1 type-aware judgment.** Documented in Always
  section: no prior `schedule_next` exists; coordinator runs cheap
  only; first verdict may use Tech-Spec signals + cycle diff to
  authorize expensive starting cycle 2.
  *Evidence:* test "(i) validator persona documents cycle-1 type-
  aware heuristic" — PASS.

- [x] **DoD 5 — `reason` cites at least one signal source.** Schema
  enforces non-empty `reason:` with citation requirement (sensor id,
  criterion id, Tech-Spec section, or runs-history entry); fixture
  validator exercises both well-formed and empty-reason cases.
  *Evidence:* tests "(k) verdict with empty reason is rejected" +
  "well-formed verdict ... passes schema check" — PASS.

- [x] **DoD 6 — Templates persist `schedule_next`.** Both
  `templates/progress.md` (per-cycle) and `templates/contracts.md`
  (per-consensus) gain a `schedule_next:` block with the locked
  shape (sensors / tiers / reason). Schema notes added to both
  templates referencing the source PRD.
  *Evidence:* tests "(j) templates/progress.md declares
  schedule_next:" + "(j) templates/contracts.md declares
  schedule_next:" + 6 sub-assertions on the sub-fields — all PASS.

- [x] **DoD 7 — Test coverage.** 28 new assertions: persona checks
  (i, 11 assertions), template checks (j, 10 assertions), fixture-
  verdict schema (k, 5 assertions covering 2 valid cases + 3 invalid
  cases). All PASS.

- [x] **DoD 8 — Craftsmanship.** Actionable-feedback rationale
  section added with explicit reconciliation against shift-feedback-
  left convention (`conventions.md:18-22`,
  `patterns/sensors.md:136`); PRD reference inline in
  `agents/validator.md`, `templates/progress.md`,
  `templates/contracts.md`; verdict schema follows existing
  structured-output convention (`schedule_next` is structured YAML,
  not prose); no manifesto invariant weakened (Validator's
  scheduling is a refinement of judgment, not a new role).

## Pattern Compliance

- [x] **`patterns/roles.md`** — followed. Validator scheduling is a
  refinement of the existing judgment role; no new role introduced;
  parallel-spawn architecture preserved (Validator emits via verdict,
  doesn't gate inside the cycle).

- [x] **`patterns/sensors.md`** — followed. The verdict and
  `schedule_next` are both structured (machine-parseable). The
  per-sensor file is now the runtime context for scheduling
  decisions, consistent with Parts 1+2 establishing `.yoke/sensors/`
  as the source of truth.

- [x] **`patterns/ralph-loop.md`** — followed. Lag-by-one model
  reused (same as the inferential-judge model documented at
  `patterns/sensors.md:90`). Parallel-spawn 3-subagent architecture
  unchanged.

- [x] **`patterns/memory-model.md`** — followed. Validator reads
  working memory directly (`.yoke/sensors/<id>.md` is project-scoped
  working memory). No canonical-memory access added.

- [x] **`conventions.md`** — followed. Every persona change traces
  to source PRD; structured output throughout (verdict +
  `schedule_next`); no canonical-memory writes; the
  shift-feedback-left rationale is reconciled, not violated.

## Convention Violations

None identified.

## Scope Discipline

Files changed: **4 / ≤ 4 budget** (exactly at limit).

- `agents/validator.md` (modified) — sensor-file reads, schedule_next
  schema, default rule, cycle-1 heuristic, rationale section
- `templates/progress.md` (modified) — `schedule_next:` per-cycle +
  schema notes
- `templates/contracts.md` (modified) — `schedule_next:` per-contract
  + schema notes
- `tests/sensor-tiering.test.sh` (modified) — Part 4 assertions

Anti-scope respected: no coordinator gating (Part 5 owns it); no
in-cycle scheduling (lag-by-one only, preserves parallel-spawn);
no live-agent integration tests (fixture-based schema check only);
no Orchestrator changes; no new persona responsibilities beyond
scheduling; no new working-memory artifacts (reuse `progress.md`
and `contracts.md`); no `schedule_next` schema versioning; no
flake-detection algorithm (qualitative interpretation only).

## Architectural notes / pitfalls discovered

1. **Markdown line-wrap matters for grep-based persona tests.** The
   initial draft of the "expensive when cheap-green" rule had the
   phrase "cheap-tier was green" wrapped across two lines (line 130-
   131 of validator.md). The persona test grepped for the literal
   phrase and failed. Reworded the rule to keep the phrase inline.
   Future persona tests should use multi-line-tolerant grep
   (`grep -Pz`) or test for word fragments rather than full phrases.

2. **`schedule_next` schema is asymmetric in the templates.**
   `progress.md` is per-cycle (Validator writes one block per cycle);
   `contracts.md` is per-contract (one block per consensus reached,
   with its own `cycle:` field). The same `schedule_next` shape lands
   in both, but in `contracts.md` it's a snapshot of the scheduling
   decision active at the cycle when consensus was reached, while in
   `progress.md` it's the live decision for the next cycle. The
   schema notes in each template document the difference.

3. **Validator's tool list does not need to change.** The persona
   already had `Read` for sensor-file access and `Write/Edit` for
   `contracts.md`. No new tools required for Part 4 — the existing
   surface is sufficient.

## Gaps

None. Verdict is PASS.

## Next steps

Ready to ship Part 4. Proceed to Part 5 — coordinator two-phase
execution + run-history persistence + pattern doc:

```
/vibeflow:implement .vibeflow/specs/sensor-cost-tiering-part-5.md
```

Part 5 is the final integration layer; it consumes Parts 1–4 and
flips the user-visible runtime behavior.
