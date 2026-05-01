# Sprint contracts

> Co-written by the Implementation Agent and the Validation Agent
> when they reach consensus on a sub-objective interpretation.
> Sprint contracts can refine the Acceptance Contract envelope but
> never relax it. A contract that contradicts the Acceptance Contract
> pauses the loop for human arbitration (Trigger 4 in Sprint 6+; in
> v0.4.0 the loop pauses with a clear message).

## Contract <id>
- id: "<short identifier, e.g. c1>"
- topic: "<ambiguity that was resolved>"
- decision: "<the agreed interpretation>"
- rationale: "<why this resolution; cite the Acceptance Contract criterion>"
- timestamp: "<iso8601>"
- agents_involved: [implementation, validation]
- references:
    - "acceptance-contract.md#<criterion id>"
- cycle: <N>
- schedule_next:
    sensors: ["<sensor-id>"]                    # optional; explicit ids
    tiers: ["cheap"]                            # at least one of sensors / tiers must be non-empty
    reason: "<must cite at least one signal source — sensor id, criterion id, Tech-Spec section, or runs: history entry>"

<!-- Subsequent contracts append below this line, one `## Contract <id>` block per consensus reached. -->

## Cycle 1 — Sprint 01 — Validator Verdicts

> Emitted by the Validator at 2026-05-01T00:00:00Z (cycle 1, sprint 01).
> No snapshot exists (`.yoke/runtime/.snapshots/` directory absent — pre-implementation).
> No inferential verdicts exist (`.yoke/runtime/.judge-verdicts/cycle-0/` absent — lag-by-one empty).
> All sensor results: absent. Rationale per `agents/validator.md` §"Always":
> treat missing snapshot as "no implementation yet" and record `fail` for
> every criterion whose gating sensor is computational or `skip` for
> inferential sensors with a lag-by-one absence.

### Criterion: Scenario 1 / FR-8 — Drift baseline captured

```json
{
  "criterion": "Scenario 1 / FR-8",
  "status": "fail",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "Invoke /yoke:drift-sense --target codebase against each of the last N>=3 post-merge SHAs; aggregate samples and append a '## Baseline metrics' section to .yoke/specs/2026-05-01-agent-council.md containing at least three SHA samples and a kLoC denominator; add tests/runtime/baseline-shape.test.sh.",
  "sensor": "drift-baseline-captured",
  "evidence": "No cycle-1.yaml snapshot exists (.yoke/runtime/.snapshots/ absent). Sensor drift-baseline-captured is computational; its verdict is absent because no implementation has landed. The binding contract FR-8 Validation block requires: pass = section exists with N>=3 samples AND kLoC denominator. Absence of implementation = fail."
}
```

### Criterion: Scenario 2 / FR-1 — Three persona files load with extended frontmatter

```json
{
  "criterion": "Scenario 2 / FR-1",
  "status": "fail",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": "Create agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md with standard Claude Code frontmatter keys (name, description, tools) plus Yoke keys (objective as single sentence, sensor-toolkit as YAML list, review-skill on sr-staff.md set to '/review'). Ensure awk extraction of sr-staff.md frontmatter yields review-skill matching '/review'. Add tests/runtime/persona-files-shape.test.sh. Add tests/runtime/fixtures/persona-frontmatter-valid.md.",
  "sensor": "persona-file-shape-valid",
  "evidence": "No cycle-1.yaml snapshot exists. Sensor persona-file-shape-valid is computational. Binding contract FR-1 Validation: pass = each shipped file's frontmatter parses AND every required key present with right type. Absence of all three files = fail. shellcheck-clean also absent for the same reason (no bash files authored yet)."
}
```

### Criterion: Scenario 3 / FR-1 — Persona schema validator fails fast on malformed files

```json
{
  "criterion": "Scenario 3 / FR-1",
  "status": "fail",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": "Create lib/runtime/persona-loader.sh exposing 'validate <path>' and 'validate-all <agents-dir>' subcommands. On any frontmatter violation emit 'wm: <message>' to stderr naming file and key, exit non-zero. Add fixture files: tests/runtime/fixtures/persona-missing-objective.md, persona-toolkit-string.md, persona-tools-missing.md (one valid, three malformed). Add tests/runtime/persona-loader.test.sh. Add bash lib/runtime/persona-loader.sh validate-all agents/ to CI smoke matrix.",
  "sensor": "persona-loader-fail-fast",
  "evidence": "No cycle-1.yaml snapshot exists. Sensor persona-loader-fail-fast is computational. Binding contract FR-1 Validation: pass = malformed fixture files exit non-zero with a 'wm: <message>' line naming the offending key; fail = exits 0 on any malformed fixture OR exits non-zero on valid one. lib/runtime/persona-loader.sh does not exist on disk. shellcheck-clean verdict also absent."
}
```

### Criterion: Scenario 4 / FR-2 — Per-persona slice protocol and deterministic merge

```json
{
  "criterion": "Scenario 4 / FR-2",
  "status": "fail",
  "location": "lib/runtime/council-merge.sh, lib/working-memory/paths.sh",
  "fix_instruction": "Create lib/runtime/council-merge.sh exposing 'merge <cycle-dir>' that reads persona slice files alphabetically and emits structured markdown to stdout (pure, no writes/LLM calls). Add path helpers wm_cycle_dir and wm_persona_slice_path to lib/working-memory/paths.sh. Create fixture at tests/runtime/fixtures/cycle-3-personas/ with three engineered persona slices. Create tests/runtime/fixtures/cycle-slice-violation/ for the slice-isolation sensor. Add tests/runtime/council-merge.test.sh. Verify two consecutive invocations produce byte-identical output.",
  "sensor": "merge-determinism",
  "evidence": "No cycle-1.yaml snapshot exists. Sensors merge-determinism and slice-protocol-isolated are computational. Binding contract FR-2 Validation: pass = cycle directory contains exactly three slice files matching persona names; phase-b-opens-after-barrier pass = every Phase B read has mtime >= latest Phase-A marker mtime. lib/runtime/council-merge.sh does not exist on disk. shellcheck-clean verdict also absent."
}
```

### Criterion: Scenario 5 / FR-2 — Sync barrier enforces mtime ordering

```json
{
  "criterion": "Scenario 5 / FR-2",
  "status": "fail",
  "location": "lib/runtime/sync-barrier.sh",
  "fix_instruction": "Create lib/runtime/sync-barrier.sh exposing 'wait-all <slug> <N> <persona-list>' (polls for phase-a-done markers with timeout) and 'clear-markers <slug> <N>' (idempotent removal of stale markers). Define marker convention .yoke/runtime/.phase-a-done.<persona>. Add tests/sensors/council-sync-barrier.test.sh covering pass fixture (all slice mtimes >= latest marker) and fail fixture (one slice mtime predates latest marker, expects exit non-zero with 'wm: sync-barrier violation:' stderr). Add tests/runtime/sync-barrier.test.sh covering wait-all success/timeout/idempotent clear-markers. Fixtures: tests/runtime/fixtures/sync-barrier-pass/ and tests/runtime/fixtures/sync-barrier-fail/.",
  "sensor": "sync-barrier-mtime-ordering",
  "evidence": "No cycle-1.yaml snapshot exists. Sensors sync-barrier-mtime-ordering and phase-a-marker-cleanup-idempotent are computational. Binding contract FR-2 Validation: sync-barrier-mtime-ordering pass = engineered pass fixture asserts mtime ordering; fail = engineered fail fixture surfaces 'wm: sync-barrier violation:' stderr. lib/runtime/sync-barrier.sh does not exist on disk. shellcheck-clean verdict also absent."
}
```

### Cycle 1 summary

All five Sprint 01 active criteria are `fail` — no implementation has landed.
No inferential sensor verdicts are applicable this cycle (lag-by-one: cycle-0 judge-verdicts directory absent).
No consensus reached; no sprint contract appended.

Sensors authorizing the next cycle to proceed:
- All five criteria remain failing; the next cycle must implement the Sprint 01 tasks.
- Computational sensors gate every criterion; no expensive inferential tier is warranted for cycle 2 (no implementation surface to judge yet).
- Cycle 2 coordinator should run cheap-only Phase A snapshot (--max-time-cost ceiling sufficient for shellcheck-clean + file-existence checks).

> Schema notes:
>
> - `schedule_next` mirrors the Validator's per-cycle decision verbatim
>   (added in v0.8.0 by sensor-cost-tiering Part 4). When consensus is
>   reached on a sub-objective, the scheduling decision active at that
>   cycle is captured here for audit. At least one of `sensors:` or
>   `tiers:` MUST be non-empty; `reason:` MUST cite at least one signal
>   source. Source PRD: `.yoke/prds/2026-04-27-sensor-cost-tiering.md`.
