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

## Cycle 2 — Sprint 01 — Validator Verdicts

> Emitted by the Validator at 2026-05-01T00:00:00Z (cycle 2, sprint 01).
> Snapshot consumed: `.yoke/runtime/.snapshots/cycle-1.yaml` — one entry:
>   `drift-baseline-captured`, status `skip`, reason "binary not found: <!--".
>   Sensor command is a placeholder (`<!-- TODO: fill -->`); per AC §"Inferential sensors"
>   note, "v3.0 ships placeholders so the gating contract is decidable".
> Inferential verdicts: `.yoke/runtime/.judge-verdicts/cycle-1/` absent — lag-by-one empty;
>   all inferential sensors treated as `skip` with missing-file evidence.
> Disk state post-cycle-1: `.yoke/specs/2026-05-01-agent-council.md` carries `## Baseline
>   metrics` section (1 heading, 3 SHA samples, kLoC denominators, findings density lines,
>   `### Averaged baseline`); `tests/runtime/baseline-shape.test.sh` exists and exits 0.
>   No persona files, no lib/runtime/persona-loader.sh, no lib/runtime/council-merge.sh,
>   no lib/runtime/sync-barrier.sh.

### Criterion: drift-baseline-committed (Scenario 1 / FR-8)

```json
{
  "criterion": "drift-baseline-committed",
  "status": "skip",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "The drift-baseline-captured sensor command is a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'v3.0 ships placeholders so the gating contract is decidable'. Per validator protocol, a skip from a placeholder sensor is gating-blocked — not pass and not technical fail. Fill the sensor command in Sprint 5+ per the AC note. Empirically, the implementation did land: the spec carries exactly one '## Baseline metrics' heading, three SHA samples, kLoC denominators, findings density lines, and an '### Averaged baseline' subsection; tests/runtime/baseline-shape.test.sh exits 0. Once the sensor placeholder is filled, re-run the sensor sweep and this criterion will resolve to pass.",
  "sensor": "drift-baseline-captured",
  "evidence": "cycle-1.yaml entry: sensor 'drift-baseline-captured', status 'skip', reason 'binary not found: <!--'. The command field in the sensor file is '<!-- TODO: fill -->' (placeholder). Per AC §'Inferential sensors' note: 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' Disk verification: grep -c '^## Baseline metrics$' .yoke/specs/2026-05-01-agent-council.md returns 1; tests/runtime/baseline-shape.test.sh exits 0. Contract interpretation guidance (FR-8 ### Validation): 'pass = section exists with N>=3 samples AND kLoC denominator'. The implementation satisfies the guidance on disk; the sensor cannot confirm it due to the placeholder. Verdict: skip (gating-blocked, not fail)."
}
```

### Criterion: persona-files-loadable (Scenario 2 / FR-1)

```json
{
  "criterion": "persona-files-loadable",
  "status": "fail",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": "Create agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md with standard Claude Code frontmatter keys (name, description, tools) plus Yoke keys: objective (single sentence), sensor-toolkit (YAML list, possibly empty), review-skill (string, set to '/review' on sr-staff.md only). Body of each file carries persona prompt with objective preamble, Phase A instructions, Phase B instructions. Cite concepts/yoke-pattern-roles in the body header. Then create tests/runtime/persona-files-shape.test.sh and fixture tests/runtime/fixtures/persona-frontmatter-valid.md. Verify: tests/runtime/persona-files-shape.test.sh exits 0 AND awk extraction of agents/sr-staff.md frontmatter yields review-skill matching '/review'.",
  "sensor": "persona-file-shape-valid",
  "evidence": "cycle-1.yaml has no entry for persona-file-shape-valid. Disk check: ls agents/ shows generator.md, orchestrator.md, semantic-judge.md, validator.md — no sr-eng.md, sr-qa.md, sr-staff.md. Sensor persona-file-shape-valid is computational (per sprint sensors block). Contract interpretation guidance (FR-1 ### Validation, bullet persona-file-shape-valid): 'pass = each shipped file frontmatter parses AND every required key present with right type; fail = any file frontmatter rejects parsing OR any required key missing.' Files do not exist = fail."
}
```

### Criterion: persona-schema-validated-at-startup (Scenario 3 / FR-1)

```json
{
  "criterion": "persona-schema-validated-at-startup",
  "status": "fail",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": "Create lib/runtime/persona-loader.sh exposing 'validate <persona-file-path>' and 'validate-all <agents-dir>'. Validator must: extract frontmatter via awk; assert presence and type of name, description, tools, objective, sensor-toolkit (list), and conditional review-skill (string when present); on any violation write 'wm: <message>' to stderr naming the file path AND the missing/malformed key, exit non-zero; on success exit 0 silently. Add fixture files: tests/runtime/fixtures/persona-missing-objective.md, tests/runtime/fixtures/persona-toolkit-string.md, tests/runtime/fixtures/persona-tools-missing.md (three malformed) and one valid fixture. Add tests/runtime/persona-loader.test.sh asserting expected exit code + stderr message for each fixture. Add CI smoke-matrix entry.",
  "sensor": "persona-loader-fail-fast",
  "evidence": "cycle-1.yaml has no entry for persona-loader-fail-fast. Disk check: ls lib/runtime/ shows only agent-config.sh — no persona-loader.sh. Sensor persona-loader-fail-fast is computational (per sprint sensors block). Contract interpretation guidance (FR-1 ### Validation, bullet persona-loader-fail-fast): 'pass = malformed fixture files exit non-zero with a wm: <message> line naming the offending key; fail = exits 0 on any malformed fixture OR exits non-zero on valid one.' File does not exist = fail."
}
```

### Criterion: slice-directory-flat-layout (Scenario 4 / FR-2)

```json
{
  "criterion": "slice-directory-flat-layout",
  "status": "fail",
  "location": "lib/runtime/council-merge.sh, lib/working-memory/paths.sh",
  "fix_instruction": "Create lib/runtime/council-merge.sh exposing 'merge <cycle-dir>' that reads persona slice files alphabetically, emits structured markdown to stdout (one '## <persona>' H2 per persona with body inlined as H3s), and exits 0. Function must be pure (no writes, no canonical memory queries, no LLM calls). Add path helpers wm_cycle_dir and wm_persona_slice_path to lib/working-memory/paths.sh, citing concepts/yoke-pattern-memory-model in the helper header. Create fixture at tests/runtime/fixtures/cycle-3-personas/ with three engineered persona slices and tests/runtime/fixtures/cycle-slice-violation/ for the slice-isolation sensor. Add tests/runtime/council-merge.test.sh: three subtests covering determinism (two consecutive invocations produce byte-identical output via diff -q), alphabetical order, and slice-isolation detection.",
  "sensor": "merge-determinism",
  "evidence": "cycle-1.yaml has no entry for merge-determinism or slice-protocol-isolated. Disk check: ls lib/runtime/ shows only agent-config.sh — no council-merge.sh. Sensors merge-determinism and slice-protocol-isolated are computational (per sprint sensors block). Contract interpretation guidance (FR-2 ### Validation, bullet phase-a-spawns-three-personas): 'pass = cycle directory contains exactly three slice files matching persona names; fail = any count other than 3 OR any slice unreadable.' Council-merge.sh does not exist = fail."
}
```

### Criterion: merge-helper-pure (Scenario 4 / FR-2 — merge purity)

```json
{
  "criterion": "merge-helper-pure",
  "status": "fail",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": "See fix_instruction for slice-directory-flat-layout above. The merge helper must be pure (no writes, no LLM calls, no canonical memory queries) and produce byte-identical output across two consecutive invocations against the same fixture cycle directory. Both properties are tested by tests/runtime/council-merge.test.sh.",
  "sensor": "merge-determinism",
  "evidence": "cycle-1.yaml has no entry for merge-determinism. Disk check: lib/runtime/council-merge.sh does not exist. Contract interpretation guidance (Scenario 4 Then clause): 'both invocations produce byte-identical output (verified by diff -q) AND the merged view orders personas alphabetically AND tests/runtime/council-merge.test.sh exits 0.' File does not exist = fail."
}
```

### Criterion: sync-barrier-enforced (Scenario 5 / FR-2)

```json
{
  "criterion": "sync-barrier-enforced",
  "status": "fail",
  "location": "lib/runtime/sync-barrier.sh",
  "fix_instruction": "Create lib/runtime/sync-barrier.sh exposing 'wait-all <slug> <N> <persona-list>' (polls for .yoke/runtime/.phase-a-done.<persona> marker files with configurable timeout, fails after timeout) and 'clear-markers <slug> <N>' (idempotent removal of leftover markers at cycle entry). Create tests/sensors/council-sync-barrier.test.sh with two engineered fixtures: pass fixture (every slice mtime >= latest marker mtime, sensor exits 0) and fail fixture (one slice mtime predates latest marker, sensor exits non-zero with 'wm: sync-barrier violation:' stderr line naming the offending slice). Create tests/runtime/sync-barrier.test.sh covering wait-all success path, timeout path, and idempotent clear-markers. Create fixture directories tests/runtime/fixtures/sync-barrier-pass/ and tests/runtime/fixtures/sync-barrier-fail/. Add both tests to CI.",
  "sensor": "sync-barrier-mtime-ordering",
  "evidence": "cycle-1.yaml has no entry for sync-barrier-mtime-ordering or phase-a-marker-cleanup-idempotent. Disk check: lib/runtime/sync-barrier.sh does not exist. Sensors sync-barrier-mtime-ordering and phase-a-marker-cleanup-idempotent are computational (per sprint sensors block). Contract interpretation guidance (FR-2 ### Validation, bullet sync-barrier-mtime-ordering): 'pass = engineered pass fixture asserts mtime ordering; fail = engineered fail fixture surfaces a wm: sync-barrier violation: stderr.' File does not exist = fail."
}
```

### Cycle 2 summary

Verdicts for the six Sprint 01 active criteria:

| Criterion | Status | Gating sensor |
|---|---|---|
| drift-baseline-committed | skip (gating-blocked — placeholder sensor) | drift-baseline-captured |
| persona-files-loadable | fail | persona-file-shape-valid |
| persona-schema-validated-at-startup | fail | persona-loader-fail-fast |
| slice-directory-flat-layout | fail | merge-determinism |
| merge-helper-pure | fail | merge-determinism |
| sync-barrier-enforced | fail | sync-barrier-mtime-ordering |

Summary: 0 pass, 5 fail, 1 skip (gating-blocked), 0 divergence. No consensus reached; no sprint contract appended. The drift-baseline-committed criterion is skip because its sensor command is a placeholder; the underlying implementation (the `## Baseline metrics` spec section) has landed correctly and `tests/runtime/baseline-shape.test.sh` exits 0 — once the placeholder is filled in Sprint 5+ this criterion will resolve to pass. The five remaining criteria are fail because their target files (persona agents, lib/runtime/persona-loader.sh, lib/runtime/council-merge.sh, lib/runtime/sync-barrier.sh) have not been created yet; cycle 1 only landed the drift baseline (Task t01). No inferential judge verdicts were available this cycle (lag-by-one: `.yoke/runtime/.judge-verdicts/cycle-1/` absent).

Cycle 3 should implement Tasks t02 and t03 in batch (persona files + persona loader are coupled: both produce against the same `agents/` directory and `lib/runtime/persona-loader.sh`). Tasks t04 and t05 (council-merge + sync-barrier) can follow in cycle 4, or be batched with t02/t03 if the Generator's plan assesses the change surface as non-overlapping.

**schedule_next for cycle 3:**

```yaml
schedule_next:
  sensors:
    - persona-file-shape-valid
    - persona-loader-fail-fast
    - shellcheck-clean
  tiers:
    - cheap
  reason: >
    Cycle 2 verdicts cite persona-files-loadable (sensor persona-file-shape-valid, status fail)
    and persona-schema-validated-at-startup (sensor persona-loader-fail-fast, status fail) as the
    highest-priority Sprint 01 failing criteria. Both sensors are cheap-tier computational checks
    (file-existence + awk frontmatter parse + exit-code assertions). shellcheck-clean must run
    against every new bash file added (lib/runtime/persona-loader.sh). Tasks t04 and t05
    (merge-determinism, sync-barrier-mtime-ordering) remain failing but are lower-priority until
    t02/t03 are resolved; include them in cycle 4 if t02/t03 converge this cycle.
```

## Cycle 3 — Sprint 01 — Validator Verdicts

> Emitted by the Validator at 2026-05-01T00:00:00Z (cycle 3, sprint 01).
> Snapshot consumed: `.yoke/runtime/.snapshots/cycle-2.yaml` — five entries, all `skip`
>   due to placeholder commands (`<!-- TODO: fill -->`): `language-policy-en-us`,
>   `no-portuguese-content`, `persona-file-shape-valid`, `persona-loader-fail-fast`,
>   `shellcheck-clean`. Per AC §"Inferential sensors" note: "v3.0 ships placeholders so
>   the gating contract is decidable." All five sensor commands are placeholders; their
>   verdicts are `skip` with reason "binary not found: <!--".
> Inferential verdicts: `.yoke/runtime/.judge-verdicts/cycle-2/` absent — lag-by-one empty;
>   all inferential sensors treated as `skip` with missing-file evidence.
> Disk state post-cycle-3: `agents/sr-eng.md`, `agents/sr-qa.md`, `agents/sr-staff.md`
>   exist with extended frontmatter (objective, sensor-toolkit list, review-skill on
>   sr-staff.md = "/review"). `lib/runtime/persona-loader.sh` exists with `validate` and
>   `validate-all` subcommands. `tests/runtime/persona-files-shape.test.sh` exits 0.
>   `tests/runtime/persona-loader.test.sh` exits 0. `bash lib/runtime/persona-loader.sh
>   validate-all agents/` exits 0.
>   `lib/runtime/council-merge.sh` absent. `lib/runtime/sync-barrier.sh` absent.
>   `tests/runtime/council-merge.test.sh` absent. `tests/runtime/sync-barrier.test.sh` absent.
>   `shellcheck` binary not available in this environment (exit 127).

### Criterion: drift-baseline-committed (Scenario 1 / FR-8)

```json
{
  "criterion": "drift-baseline-committed",
  "status": "skip",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "The drift-baseline-captured sensor command is a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'v3.0 ships placeholders so the gating contract is decidable'. This is a skip (gating-blocked), not a technical fail. Fill the sensor command in Sprint 5+ per the AC note. Empirically the implementation has landed since cycle 1: the spec carries exactly one '## Baseline metrics' heading, three SHA samples, kLoC denominators, and an '### Averaged baseline' subsection; tests/runtime/baseline-shape.test.sh exits 0.",
  "sensor": "drift-baseline-captured",
  "evidence": "cycle-2.yaml entry: sensor 'drift-baseline-captured' absent (sensor was not listed in cycle-2.yaml; cycle-2.yaml lists language-policy-en-us, no-portuguese-content, persona-file-shape-valid, persona-loader-fail-fast, shellcheck-clean — all skip due to placeholder commands). Per-sensor file .yoke/sensors/drift-baseline-captured.md: command = '<!-- TODO: fill -->' (placeholder). AC FR-8 ### Validation: 'pass = section exists with N>=3 samples AND kLoC denominator'. Disk state confirmed in cycle 2: grep returns 1 for the heading; tests/runtime/baseline-shape.test.sh exits 0. Criterion verdict: skip (gating-blocked by placeholder; underlying implementation confirmed on disk)."
}
```

### Criterion: persona-files-loadable (Scenario 2 / FR-1)

```json
{
  "criterion": "persona-files-loadable",
  "status": "skip",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": "The persona-file-shape-valid sensor command is a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked by placeholder), not a technical fail. The underlying implementation has landed this cycle: agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md all exist with the required extended frontmatter (name, description, tools, objective, sensor-toolkit list, review-skill on sr-staff.md = '/review'). tests/runtime/persona-files-shape.test.sh exits 0. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-file-shape-valid",
  "evidence": "cycle-2.yaml entry: persona-file-shape-valid status=skip, reason='binary not found: <!--'. Per-sensor file .yoke/sensors/persona-file-shape-valid.md: command='<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-file-shape-valid: 'pass = each shipped file frontmatter parses AND every required key present with right type; fail = any file frontmatter rejects parsing OR any required key missing.' Disk verification this cycle: agents/sr-eng.md frontmatter awk-extracted confirms name, description, tools, objective, sensor-toolkit (list), review-skill=''; agents/sr-qa.md same pattern; agents/sr-staff.md frontmatter shows review-skill='/review'. bash lib/runtime/persona-loader.sh validate-all agents/ exits 0. tests/runtime/persona-files-shape.test.sh exits 0. Verdict: skip (gating-blocked; implementation confirmed on disk)."
}
```

### Criterion: persona-schema-validated-at-startup (Scenario 3 / FR-1)

```json
{
  "criterion": "persona-schema-validated-at-startup",
  "status": "skip",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": "The persona-loader-fail-fast sensor command is a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked by placeholder), not a technical fail. The underlying implementation has landed this cycle: lib/runtime/persona-loader.sh exists with validate and validate-all subcommands; tests/runtime/persona-loader.test.sh exits 0; validate-all agents/ exits 0. Malformed fixture files produce non-zero exit with wm:-prefixed stderr per the AC criterion. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-loader-fail-fast",
  "evidence": "cycle-2.yaml entry: persona-loader-fail-fast status=skip, reason='binary not found: <!--'. Per-sensor file .yoke/sensors/persona-loader-fail-fast.md: command='<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-loader-fail-fast: 'pass = malformed fixture files exit non-zero with a wm: <message> line naming the offending key; fail = exits 0 on any malformed fixture OR exits non-zero on valid one.' Disk verification this cycle: lib/runtime/persona-loader.sh exists; tests/runtime/persona-loader.test.sh exits 0 (covers valid fixture exit 0 + malformed fixtures persona-missing-objective.md, persona-toolkit-string.md, persona-tools-missing.md each exit non-zero with wm:-prefixed stderr); bash lib/runtime/persona-loader.sh validate-all agents/ exits 0. Verdict: skip (gating-blocked; implementation confirmed on disk)."
}
```

### Criterion: slice-directory-flat-layout (Scenario 4 / FR-2)

```json
{
  "criterion": "slice-directory-flat-layout",
  "status": "fail",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": "Create lib/runtime/council-merge.sh exposing 'merge <cycle-dir>' that reads persona slice files alphabetically, emits structured markdown to stdout (one '## <persona>' H2 per persona with body inlined as H3s), exits 0. Function must be pure (no writes, no canonical-memory queries, no LLM calls). Add path helpers wm_cycle_dir and wm_persona_slice_path to lib/working-memory/paths.sh, citing concepts/yoke-pattern-memory-model in the helper header. Create fixture tests/runtime/fixtures/cycle-3-personas/ with three engineered persona slices and tests/runtime/fixtures/cycle-slice-violation/ for the slice-isolation sensor. Add tests/runtime/council-merge.test.sh covering determinism (two consecutive invocations produce byte-identical stdout via diff -q), alphabetical ordering, and slice-isolation detection.",
  "sensor": "merge-determinism",
  "evidence": "cycle-2.yaml has no entry for merge-determinism (not in the snapshot's five sensor entries). Per-sensor file .yoke/sensors/merge-determinism.md: command='<!-- TODO: fill -->' (placeholder). However: disk check confirms lib/runtime/council-merge.sh is ABSENT (ls lib/runtime/ returns agent-config.sh, persona-loader.sh only). tests/runtime/fixtures/cycle-3-personas/ is ABSENT. tests/runtime/council-merge.test.sh is ABSENT. AC Scenario 4 ### Validation: sensor merge-determinism is the gating sensor; AC FR-2 Validation block: 'pass = cycle directory contains exactly three slice files matching persona names'. No implementation landed for Task t04. Verdict: fail (file absent — placeholder sensor is irrelevant because the underlying implementation itself does not exist)."
}
```

### Criterion: merge-helper-pure (Scenario 4 / FR-2 — merge purity)

```json
{
  "criterion": "merge-helper-pure",
  "status": "fail",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": "Same as slice-directory-flat-layout above. The merge helper must additionally produce byte-identical output across two consecutive invocations against the same fixture cycle directory (verified by diff -q). Both determinism and purity are tested by tests/runtime/council-merge.test.sh. No separate file is required; both criteria are gated by the same lib/runtime/council-merge.sh and tests/runtime/council-merge.test.sh.",
  "sensor": "merge-determinism",
  "evidence": "Per-sensor file .yoke/sensors/merge-determinism.md: command='<!-- TODO: fill -->' (placeholder). Disk check: lib/runtime/council-merge.sh ABSENT. AC Scenario 4 Then clause: 'both invocations produce byte-identical output (verified by diff -q) AND the merged view orders personas alphabetically AND tests/runtime/council-merge.test.sh exits 0'. No implementation exists for the merge purity property. Verdict: fail (lib/runtime/council-merge.sh absent — cannot evaluate purity or determinism)."
}
```

### Criterion: sync-barrier-enforced (Scenario 5 / FR-2)

```json
{
  "criterion": "sync-barrier-enforced",
  "status": "fail",
  "location": "lib/runtime/sync-barrier.sh",
  "fix_instruction": "Create lib/runtime/sync-barrier.sh exposing 'wait-all <slug> <N> <persona-list>' (polls for .yoke/runtime/.phase-a-done.<persona> markers with configurable timeout, fails after timeout) and 'clear-markers <slug> <N>' (idempotent removal of leftover markers). Create tests/sensors/council-sync-barrier.test.sh with pass fixture (every slice mtime >= latest marker, exits 0) and fail fixture (one slice mtime predates latest marker, exits non-zero with 'wm: sync-barrier violation:' stderr naming the offending slice). Create tests/runtime/sync-barrier.test.sh covering wait-all success path, timeout path, idempotent clear-markers. Create fixture directories tests/runtime/fixtures/sync-barrier-pass/ and tests/runtime/fixtures/sync-barrier-fail/. Add both tests to CI.",
  "sensor": "sync-barrier-mtime-ordering",
  "evidence": "cycle-2.yaml has no entry for sync-barrier-mtime-ordering or phase-a-marker-cleanup-idempotent (not in the snapshot's five sensor entries). Per-sensor file .yoke/sensors/sync-barrier-mtime-ordering.md: command='<!-- TODO: fill -->' (placeholder). Disk check: lib/runtime/sync-barrier.sh ABSENT. tests/runtime/sync-barrier.test.sh ABSENT. tests/sensors/council-sync-barrier.test.sh ABSENT. tests/runtime/fixtures/sync-barrier-pass/ ABSENT. tests/runtime/fixtures/sync-barrier-fail/ ABSENT. AC FR-2 ### Validation bullet sync-barrier-mtime-ordering: 'pass = engineered pass fixture asserts mtime ordering; fail = engineered fail fixture surfaces a wm: sync-barrier violation: stderr.' No implementation exists. Verdict: fail (lib/runtime/sync-barrier.sh absent)."
}
```

### Cycle 3 summary

Verdicts for the six Sprint 01 active criteria:

| Criterion | Status | Gating sensor |
|---|---|---|
| drift-baseline-committed | skip (gating-blocked — placeholder sensor) | drift-baseline-captured |
| persona-files-loadable | skip (gating-blocked — placeholder sensor; implementation confirmed on disk) | persona-file-shape-valid |
| persona-schema-validated-at-startup | skip (gating-blocked — placeholder sensor; implementation confirmed on disk) | persona-loader-fail-fast |
| slice-directory-flat-layout | fail | merge-determinism |
| merge-helper-pure | fail | merge-determinism |
| sync-barrier-enforced | fail | sync-barrier-mtime-ordering |

Summary: 0 pass, 3 fail, 3 skip (gating-blocked), 0 divergence. No consensus reached; no sprint contract appended.

Cycle 3 shipped Tasks t02 and t03 (persona files + persona-loader): all three persona agent files exist with the required extended frontmatter, `lib/runtime/persona-loader.sh` is functional, both test suites (`tests/runtime/persona-files-shape.test.sh`, `tests/runtime/persona-loader.test.sh`) exit 0, and `validate-all agents/` exits 0. The `shellcheck-clean` sensor is gating-blocked because `shellcheck` is unavailable in this environment (exit 127); per AC §"Applicable policies", this does not promote to a hard fail without a confirmed sensor verdict — it remains gating-blocked pending a CI run where the tool is available.

Tasks t04 (council-merge) and t05 (sync-barrier) remain unimplemented. Three criteria (`slice-directory-flat-layout`, `merge-helper-pure`, `sync-barrier-enforced`) are `fail` because their target files do not exist on disk — the placeholder sensor status is irrelevant to this determination; absence of implementation is a direct fail per any-fail-wins.

Placeholder coverage: 3 of 6 active criteria are gating-blocked by placeholder sensors per AC §"Inferential sensors" design. This is documented behavior, not a divergence. Sprint 01 will not converge until placeholder sensors are filled (Sprint 5+ per AC) or the AC is amended via Trigger 3.

**schedule_next for cycle 4:**

```yaml
schedule_next:
  sensors:
    - merge-determinism
    - slice-protocol-isolated
    - sync-barrier-mtime-ordering
    - phase-a-marker-cleanup-idempotent
    - shellcheck-clean
  tiers:
    - cheap
  reason: >
    Cycle 3 verdicts cite slice-directory-flat-layout (sensor merge-determinism, status fail),
    merge-helper-pure (sensor merge-determinism, status fail), and sync-barrier-enforced
    (sensor sync-barrier-mtime-ordering, status fail) as the three outstanding failing
    criteria for Sprint 01. FR-2 Validation lists merge-determinism + slice-protocol-isolated
    as the gating sensors for Scenario 4, and sync-barrier-mtime-ordering +
    phase-a-marker-cleanup-idempotent as the gating sensors for Scenario 5. shellcheck-clean
    must run against every new bash file added by t04/t05 (lib/runtime/council-merge.sh,
    lib/runtime/sync-barrier.sh, tests/runtime/council-merge.test.sh,
    tests/runtime/sync-barrier.test.sh). All five are cheap-tier (time_cost: 30 each).
```

## Cycle 4 — Sprint 01 — Validator Verdicts

> Emitted by the Validator at 2026-05-01T00:00:00Z (cycle 4, sprint 01).
> Snapshot consumed: `.yoke/runtime/.snapshots/cycle-3.yaml` — seven entries, all `skip`
>   due to placeholder commands (`<!-- TODO: fill -->`): `merge-determinism`,
>   `phase-a-marker-cleanup-idempotent`, `phase-a-spawns-three-personas`,
>   `phase-b-opens-after-barrier`, `shellcheck-clean`, `slice-protocol-isolated`,
>   `sync-barrier-mtime-ordering`. All sensor commands are placeholders; verdicts are
>   `skip` with reason "binary not found: <!--".
> Inferential verdicts: `.yoke/runtime/.judge-verdicts/cycle-3/` absent — lag-by-one empty;
>   all inferential sensors treated as `skip` with missing-file evidence.
> Disk state post-cycle-4 (cycle 3 shipped t04; cycle 4 targeted t05):
>   `lib/runtime/council-merge.sh` present. `tests/runtime/council-merge.test.sh` present.
>   `tests/runtime/fixtures/cycle-3-personas/` present (sr-eng.md, sr-qa.md, sr-staff.md).
>   `tests/runtime/fixtures/cycle-slice-violation/` present (sr-eng.md, sr-qa.md).
>   `lib/runtime/sync-barrier.sh` ABSENT. `tests/runtime/sync-barrier.test.sh` ABSENT.
>   `tests/sensors/council-sync-barrier.test.sh` ABSENT.
>   `tests/runtime/fixtures/sync-barrier-pass/` ABSENT.
>   `tests/runtime/fixtures/sync-barrier-fail/` ABSENT.

### Criterion: drift-baseline-committed (Scenario 1 / FR-8)

```json
{
  "criterion": "drift-baseline-committed",
  "status": "skip",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "The drift-baseline-captured sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. Fill the sensor command in Sprint 5+ per the AC note. The underlying implementation has been confirmed since cycle 1: spec carries exactly one '## Baseline metrics' heading with three SHA samples, kLoC denominators, and an '### Averaged baseline' subsection; tests/runtime/baseline-shape.test.sh exits 0.",
  "sensor": "drift-baseline-captured",
  "evidence": "cycle-3.yaml: sensor 'drift-baseline-captured' not listed in the seven snapshot entries (snapshot covers merge-determinism, phase-a-marker-cleanup-idempotent, phase-a-spawns-three-personas, phase-b-opens-after-barrier, shellcheck-clean, slice-protocol-isolated, sync-barrier-mtime-ordering). Per-sensor command is '<!-- TODO: fill -->' (placeholder). AC FR-8 ### Validation: 'pass = section exists with N>=3 samples AND kLoC denominator'. Disk state: confirmed present since cycle 1; no regression. Judge verdicts cycle-3/ absent — lag-by-one empty. Verdict: skip (gating-blocked by placeholder; underlying implementation confirmed on disk per cycles 1-3)."
}
```

### Criterion: persona-files-loadable (Scenario 2 / FR-1)

```json
{
  "criterion": "persona-files-loadable",
  "status": "skip",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": "The persona-file-shape-valid sensor command remains a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked), not a technical fail. The implementation has been confirmed since cycle 2: agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md exist with extended frontmatter (name, description, tools, objective, sensor-toolkit list, review-skill on sr-staff.md = '/review'). tests/runtime/persona-files-shape.test.sh exits 0. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-file-shape-valid",
  "evidence": "cycle-3.yaml: sensor 'persona-file-shape-valid' not listed in the seven snapshot entries. Per-sensor command is '<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-file-shape-valid: 'pass = each shipped file frontmatter parses AND every required key present with right type; fail = any file frontmatter rejects parsing OR any required key missing.' Disk state: implementation confirmed since cycle 2 via cycle-3 Validator verification; no regression in cycle 4 (no persona agent files modified this cycle). Judge verdicts cycle-3/ absent. Verdict: skip (gating-blocked by placeholder; implementation confirmed on disk)."
}
```

### Criterion: persona-schema-validated-at-startup (Scenario 3 / FR-1)

```json
{
  "criterion": "persona-schema-validated-at-startup",
  "status": "skip",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": "The persona-loader-fail-fast sensor command remains a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked), not a technical fail. The implementation has been confirmed since cycle 2: lib/runtime/persona-loader.sh exists with validate and validate-all subcommands; tests/runtime/persona-loader.test.sh exits 0; validate-all agents/ exits 0; malformed fixture files produce non-zero exit with wm:-prefixed stderr. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-loader-fail-fast",
  "evidence": "cycle-3.yaml: sensor 'persona-loader-fail-fast' not listed in the seven snapshot entries. Per-sensor command is '<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-loader-fail-fast: 'pass = malformed fixture files exit non-zero with a wm: <message> line naming the offending key; fail = exits 0 on any malformed fixture OR exits non-zero on valid one.' Disk state: implementation confirmed since cycle 2; no regression in cycle 4. Judge verdicts cycle-3/ absent. Verdict: skip (gating-blocked by placeholder; implementation confirmed on disk)."
}
```

### Criterion: slice-directory-flat-layout (Scenario 4 / FR-2)

```json
{
  "criterion": "slice-directory-flat-layout",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh, tests/runtime/fixtures/cycle-3-personas/",
  "fix_instruction": "The merge-determinism sensor command is a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked), not a technical fail. The underlying implementation has now landed (cycle 3 / Task t04): lib/runtime/council-merge.sh exists, tests/runtime/fixtures/cycle-3-personas/ contains three slice files (sr-eng.md, sr-qa.md, sr-staff.md), tests/runtime/fixtures/cycle-slice-violation/ contains sr-eng.md and sr-qa.md, and tests/runtime/council-merge.test.sh exists. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "merge-determinism",
  "evidence": "cycle-3.yaml: sensor 'merge-determinism' listed with status='skip', reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC Scenario 4 / FR-2 ### Validation bullet merge-determinism is the gating sensor. Disk state: lib/runtime/council-merge.sh present; tests/runtime/council-merge.test.sh present; tests/runtime/fixtures/cycle-3-personas/ contains sr-eng.md, sr-qa.md, sr-staff.md; tests/runtime/fixtures/cycle-slice-violation/ contains sr-eng.md, sr-qa.md. Task t04 implementation confirmed on disk this cycle (first cycle where it is present). Judge verdicts cycle-3/ absent. Verdict: skip (gating-blocked by placeholder; underlying implementation confirmed on disk — changed from fail in cycle 3 to skip in cycle 4 because t04 landed)."
}
```

### Criterion: merge-helper-pure (Scenario 4 / FR-2 — merge purity)

```json
{
  "criterion": "merge-helper-pure",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": "The merge-determinism sensor command is a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked), not a technical fail. The implementation has landed (cycle 3 / Task t04): lib/runtime/council-merge.sh exists and is documented as a pure function (no writes, no LLM calls, no canonical-memory queries). The determinism property (two consecutive invocations produce byte-identical output via diff -q) is covered by tests/runtime/council-merge.test.sh. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "merge-determinism",
  "evidence": "cycle-3.yaml: sensor 'merge-determinism' status='skip', reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC Scenario 4 Then clause: 'both invocations produce byte-identical output (verified by diff -q) AND the merged view orders personas alphabetically AND tests/runtime/council-merge.test.sh exits 0.' Disk state: lib/runtime/council-merge.sh present; tests/runtime/council-merge.test.sh present. Task t04 landed this cycle (cycle 3). Judge verdicts cycle-3/ absent. Verdict: skip (gating-blocked by placeholder; implementation confirmed — changed from fail in cycle 3 to skip in cycle 4)."
}
```

### Criterion: sync-barrier-enforced (Scenario 5 / FR-2)

```json
{
  "criterion": "sync-barrier-enforced",
  "status": "fail",
  "location": "lib/runtime/sync-barrier.sh",
  "fix_instruction": "Task t05 has not landed. Create lib/runtime/sync-barrier.sh exposing 'wait-all <slug> <N> <persona-list>' (polls for .yoke/runtime/.phase-a-done.<persona> marker files with configurable timeout, fails after timeout) and 'clear-markers <slug> <N>' (idempotent removal of leftover markers at cycle entry). Create tests/sensors/council-sync-barrier.test.sh with two engineered fixtures: pass fixture (every slice mtime >= latest marker mtime, sensor exits 0) and fail fixture (one slice mtime predates latest marker, exits non-zero with 'wm: sync-barrier violation:' stderr naming the offending slice). Create tests/runtime/sync-barrier.test.sh covering wait-all success path, timeout path, and idempotent clear-markers. Create fixture directories tests/runtime/fixtures/sync-barrier-pass/ and tests/runtime/fixtures/sync-barrier-fail/. Add both tests to CI.",
  "sensor": "sync-barrier-mtime-ordering",
  "evidence": "cycle-3.yaml: sensor 'sync-barrier-mtime-ordering' status='skip', reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-2 ### Validation bullet sync-barrier-mtime-ordering: 'pass = engineered pass fixture asserts mtime ordering; fail = engineered fail fixture surfaces a wm: sync-barrier violation: stderr.' Disk verification: lib/runtime/sync-barrier.sh ABSENT. tests/runtime/sync-barrier.test.sh ABSENT. tests/sensors/council-sync-barrier.test.sh ABSENT. tests/runtime/fixtures/sync-barrier-pass/ ABSENT. tests/runtime/fixtures/sync-barrier-fail/ ABSENT. Task t05 target files entirely absent. Placeholder sensor is irrelevant: per any-fail-wins, absence of implementation is a direct fail independent of sensor placeholder status. Judge verdicts cycle-3/ absent. Verdict: fail (lib/runtime/sync-barrier.sh and all required test/fixture files absent on disk)."
}
```

### Cycle 4 summary

Verdicts for the six Sprint 01 active criteria:

| Criterion | Status | Gating sensor | Notes |
|---|---|---|---|
| drift-baseline-committed | skip (gating-blocked) | drift-baseline-captured | Implementation confirmed since cycle 1; placeholder sensor blocks pass |
| persona-files-loadable | skip (gating-blocked) | persona-file-shape-valid | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| persona-schema-validated-at-startup | skip (gating-blocked) | persona-loader-fail-fast | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| slice-directory-flat-layout | skip (gating-blocked) | merge-determinism | Implementation landed cycle 3 (Task t04); placeholder sensor blocks pass |
| merge-helper-pure | skip (gating-blocked) | merge-determinism | Implementation landed cycle 3 (Task t04); placeholder sensor blocks pass |
| sync-barrier-enforced | fail | sync-barrier-mtime-ordering | Task t05 not yet landed; all target files absent on disk |

Summary: 0 pass, 1 fail, 5 skip (gating-blocked), 0 divergence. No consensus reached; no sprint contract appended.

**STRUCTURAL OBSERVATION.** Sprint 01 has now shipped Tasks t01 through t04 at the file level (five tasks across cycles 1-3; t04 is the most recent). Only one task — t05 (sync-barrier) — remains unimplemented, and that is the sole `fail` criterion this cycle. However, every gating sensor for all six Sprint 01 criteria remains a placeholder (`<!-- TODO: fill -->`) per AC §"Inferential sensors": "Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable." This means Sprint 01 cannot organically converge through `verify-acceptance.sh` even after t05 lands, because no sensor can return a genuine `pass` verdict — the coordinator's single per-cycle `verify-acceptance.sh` execution will continue to emit `skip` for every criterion. The sprint cannot reach the binding contract's "done" definition until placeholder sensors are filled (Sprint 5+ per AC) or the AC's gating semantics are amended via a fresh ratification round (Trigger 3). If cycle 5 lands t05 and all six criteria remain gating-blocked with no further implementation to ship, the Orchestrator should surface this as an arbitration point for the user: decide whether to (a) carry Sprint 01 as perpetually gating-blocked pending Sprint 5+ sensor fills, (b) ratify an AC amendment that declares placeholder-gated criteria as pass-by-attestation, or (c) immediately fill the sensor placeholders as a Sprint 01 unblocking step.

**schedule_next for cycle 5:**

```yaml
schedule_next:
  sensors:
    - sync-barrier-mtime-ordering
    - phase-a-marker-cleanup-idempotent
    - shellcheck-clean
  tiers:
    - cheap
  reason: >
    Cycle 4 verdicts: sync-barrier-enforced (sensor sync-barrier-mtime-ordering, status fail)
    is the only remaining fail criterion for Sprint 01; it gates Task t05
    (lib/runtime/sync-barrier.sh + tests + fixtures). AC FR-2 ### Validation lists
    sync-barrier-mtime-ordering and phase-a-marker-cleanup-idempotent as the gating sensors
    for Scenario 5. shellcheck-clean must run against every new bash file added by t05
    (lib/runtime/sync-barrier.sh, tests/runtime/sync-barrier.test.sh,
    tests/sensors/council-sync-barrier.test.sh). All three are cheap-tier sensors.
    The five skip criteria remain gating-blocked by placeholder sensors; no sensor sweep
    will resolve them until Sprint 5+ fills the placeholders or the AC is amended.
```

## Cycle 5 — Sprint 01 — Validator Verdicts

> Emitted by the Validator at 2026-05-01T00:00:00Z (cycle 5, sprint 01).
> Snapshot consumed: `.yoke/runtime/.snapshots/cycle-4.yaml` — three entries, all `skip`
>   due to placeholder commands (`<!-- TODO: fill -->` or bare `|`):
>   `phase-a-marker-cleanup-idempotent` (reason: "binary not found: <!--"),
>   `shellcheck-clean` (reason: "binary not found: |"),
>   `sync-barrier-mtime-ordering` (reason: "binary not found: <!--").
>   All sensor commands are placeholders; verdicts are `skip`.
> Inferential verdicts: `.yoke/runtime/.judge-verdicts/cycle-4/` absent — lag-by-one empty;
>   all inferential sensors treated as `skip` with missing-file evidence.
> Disk state post-cycle-5 (Generator confirmed zero actionable work remaining; all 5 tasks shipped):
>   `lib/runtime/sync-barrier.sh` present. `tests/runtime/sync-barrier.test.sh` present.
>   `tests/sensors/council-sync-barrier.test.sh` present.
>   `tests/runtime/fixtures/sync-barrier-pass/` present.
>   `tests/runtime/fixtures/sync-barrier-fail/` present.
>   All prior cycle artifacts confirmed present (no regressions detected).

### Criterion: drift-baseline-committed (Scenario 1 / FR-8)

```json
{
  "criterion": "drift-baseline-committed",
  "status": "skip",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "The drift-baseline-captured sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. Fill the sensor command in Sprint 5+ per the AC note. The underlying implementation has been confirmed since cycle 1: spec carries exactly one '## Baseline metrics' heading with three SHA samples, kLoC denominators, and an '### Averaged baseline' subsection; tests/runtime/baseline-shape.test.sh exits 0.",
  "sensor": "drift-baseline-captured",
  "evidence": "Cycle-4 snapshot: sensor 'drift-baseline-captured' not listed in the three snapshot entries (snapshot covers phase-a-marker-cleanup-idempotent, shellcheck-clean, sync-barrier-mtime-ordering). Per-sensor command is '<!-- TODO: fill -->' (placeholder). AC FR-8 ### Validation: 'pass = section exists with N>=3 samples AND kLoC denominator'. Disk state: implementation confirmed since cycle 1; no regression in cycle 5. Judge verdicts cycle-4/ absent — lag-by-one empty. Verdict: skip (gating-blocked by placeholder sensor command per AC §'Inferential sensors'; underlying implementation confirmed on disk across cycles 1-5)."
}
```

### Criterion: persona-files-loadable (Scenario 2 / FR-1)

```json
{
  "criterion": "persona-files-loadable",
  "status": "skip",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": "The persona-file-shape-valid sensor command remains a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked), not a technical fail. The implementation has been confirmed since cycle 2: agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md exist with extended frontmatter (name, description, tools, objective, sensor-toolkit list, review-skill on sr-staff.md = '/review'). tests/runtime/persona-files-shape.test.sh exits 0. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-file-shape-valid",
  "evidence": "Cycle-4 snapshot: sensor 'persona-file-shape-valid' not listed in the three snapshot entries. Per-sensor command is '<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-file-shape-valid: 'pass = each shipped file frontmatter parses AND every required key present with right type; fail = any file frontmatter rejects parsing OR any required key missing.' Disk state: implementation confirmed since cycle 2; no regression in cycle 5 (no persona agent files modified). Judge verdicts cycle-4/ absent. Verdict: skip (gating-blocked by placeholder sensor command per AC §'Inferential sensors'; implementation confirmed on disk)."
}
```

### Criterion: persona-schema-validated-at-startup (Scenario 3 / FR-1)

```json
{
  "criterion": "persona-schema-validated-at-startup",
  "status": "skip",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": "The persona-loader-fail-fast sensor command remains a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked), not a technical fail. The implementation has been confirmed since cycle 2: lib/runtime/persona-loader.sh exists with validate and validate-all subcommands; tests/runtime/persona-loader.test.sh exits 0; validate-all agents/ exits 0; malformed fixture files produce non-zero exit with wm:-prefixed stderr. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-loader-fail-fast",
  "evidence": "Cycle-4 snapshot: sensor 'persona-loader-fail-fast' not listed in the three snapshot entries. Per-sensor command is '<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-loader-fail-fast: 'pass = malformed fixture files exit non-zero with a wm: <message> line naming the offending key; fail = exits 0 on any malformed fixture OR exits non-zero on valid one.' Disk state: implementation confirmed since cycle 2; no regression in cycle 5. Judge verdicts cycle-4/ absent. Verdict: skip (gating-blocked by placeholder sensor command per AC §'Inferential sensors'; implementation confirmed on disk)."
}
```

### Criterion: slice-directory-flat-layout (Scenario 4 / FR-2)

```json
{
  "criterion": "slice-directory-flat-layout",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh, tests/runtime/fixtures/cycle-3-personas/",
  "fix_instruction": "The merge-determinism sensor command remains a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked), not a technical fail. The underlying implementation landed in cycle 3 (Task t04): lib/runtime/council-merge.sh exists, tests/runtime/fixtures/cycle-3-personas/ contains three slice files (sr-eng.md, sr-qa.md, sr-staff.md), tests/runtime/fixtures/cycle-slice-violation/ contains sr-eng.md and sr-qa.md, and tests/runtime/council-merge.test.sh exists. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "merge-determinism",
  "evidence": "Cycle-4 snapshot: sensor 'merge-determinism' not listed in the three snapshot entries (snapshot covers phase-a-marker-cleanup-idempotent, shellcheck-clean, sync-barrier-mtime-ordering). Per-sensor command is '<!-- TODO: fill -->' (placeholder). AC Scenario 4 / FR-2 ### Validation: merge-determinism is the gating sensor. Disk state: lib/runtime/council-merge.sh present; tests/runtime/council-merge.test.sh present; tests/runtime/fixtures/cycle-3-personas/ and cycle-slice-violation/ present; no regression in cycle 5. Judge verdicts cycle-4/ absent. Verdict: skip (gating-blocked by placeholder sensor command per AC §'Inferential sensors'; implementation confirmed on disk since cycle 3)."
}
```

### Criterion: merge-helper-pure (Scenario 4 / FR-2 — merge purity)

```json
{
  "criterion": "merge-helper-pure",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": "The merge-determinism sensor command remains a placeholder ('<!-- TODO: fill -->'). This is a skip (gating-blocked), not a technical fail. The implementation landed in cycle 3 (Task t04): lib/runtime/council-merge.sh exists and is documented as a pure function (no writes, no LLM calls, no canonical-memory queries); determinism property is covered by tests/runtime/council-merge.test.sh. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "merge-determinism",
  "evidence": "Cycle-4 snapshot: sensor 'merge-determinism' not listed in the three snapshot entries. Per-sensor command is '<!-- TODO: fill -->' (placeholder). AC Scenario 4 Then clause: 'both invocations produce byte-identical output (verified by diff -q) AND the merged view orders personas alphabetically AND tests/runtime/council-merge.test.sh exits 0.' Disk state: lib/runtime/council-merge.sh present; tests/runtime/council-merge.test.sh present; no regression in cycle 5. Judge verdicts cycle-4/ absent. Verdict: skip (gating-blocked by placeholder sensor command per AC §'Inferential sensors'; implementation confirmed on disk since cycle 3)."
}
```

### Criterion: sync-barrier-enforced (Scenario 5 / FR-2)

```json
{
  "criterion": "sync-barrier-enforced",
  "status": "skip",
  "location": "lib/runtime/sync-barrier.sh",
  "fix_instruction": "The sync-barrier-mtime-ordering sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying implementation has now landed in cycle 5 (Task t05): lib/runtime/sync-barrier.sh exists, tests/runtime/sync-barrier.test.sh exists, tests/sensors/council-sync-barrier.test.sh exists, tests/runtime/fixtures/sync-barrier-pass/ exists, tests/runtime/fixtures/sync-barrier-fail/ exists. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "sync-barrier-mtime-ordering",
  "evidence": "Cycle-4 snapshot: sensor 'sync-barrier-mtime-ordering' status='skip', reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-2 ### Validation bullet sync-barrier-mtime-ordering: 'pass = engineered pass fixture asserts mtime ordering; fail = engineered fail fixture surfaces a wm: sync-barrier violation: stderr.' Disk verification cycle 5: lib/runtime/sync-barrier.sh PRESENT (changed from ABSENT in cycle 4 to PRESENT in cycle 5 — Task t05 landed). tests/runtime/sync-barrier.test.sh PRESENT. tests/sensors/council-sync-barrier.test.sh PRESENT. tests/runtime/fixtures/sync-barrier-pass/ PRESENT. tests/runtime/fixtures/sync-barrier-fail/ PRESENT. Placeholder sensor is gating-blocked; per any-fail-wins, once the implementation is present the blocking condition shifts from 'file absent' to 'sensor placeholder blocks pass verdict'. Verdict: skip (gating-blocked by placeholder sensor command; implementation confirmed on disk this cycle — changed from fail in cycle 4 to skip in cycle 5 because t05 landed)."
}
```

### Cycle 5 summary

Verdicts for the six Sprint 01 active criteria:

| Criterion | Status | Gating sensor | Notes |
|---|---|---|---|
| drift-baseline-committed | skip (gating-blocked) | drift-baseline-captured | Implementation confirmed since cycle 1; placeholder sensor blocks pass |
| persona-files-loadable | skip (gating-blocked) | persona-file-shape-valid | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| persona-schema-validated-at-startup | skip (gating-blocked) | persona-loader-fail-fast | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| slice-directory-flat-layout | skip (gating-blocked) | merge-determinism | Implementation confirmed since cycle 3 (Task t04); placeholder sensor blocks pass |
| merge-helper-pure | skip (gating-blocked) | merge-determinism | Implementation confirmed since cycle 3 (Task t04); placeholder sensor blocks pass |
| sync-barrier-enforced | skip (gating-blocked) | sync-barrier-mtime-ordering | Implementation landed cycle 5 (Task t05); placeholder sensor blocks pass |

Summary: 0 pass, 0 fail, 6 skip (gating-blocked), 0 divergence.

All five Sprint 01 tasks (t01 through t05) have now shipped at the file level across cycles 1-5. Zero actionable file-level work remains for Sprint 01. Every gating sensor for every criterion remains a placeholder (`<!-- TODO: fill -->`) per AC §"Inferential sensors": "Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable." The loop is mechanically advancing toward the per-sprint hard bound (8) per user-chosen path (C). No further file-level implementation is actionable; no Trigger 4 escalation is warranted — the structural blocker (placeholder sensors) is documented AC behavior, not a divergence. The Orchestrator handles hard-bound escalation at cycle 8 if the loop reaches it.

**schedule_next for cycle 6 (same as cycle 4/5 — structural blocker unchanged):**

```yaml
schedule_next:
  sensors:
    - sync-barrier-mtime-ordering
    - phase-a-marker-cleanup-idempotent
    - shellcheck-clean
  tiers:
    - cheap
  reason: >
    Cycle 5 verdicts: all six Sprint 01 criteria are skip (gating-blocked by placeholder
    sensor commands per AC §'Inferential sensors'). No file-level work remains — all
    five tasks (t01-t05) have shipped on disk. The structural blocker is the placeholder
    sensor commands across every gating sensor; no verify-acceptance.sh run can return
    genuine pass verdicts until Sprint 5+ fills the placeholders or the AC is amended
    via Trigger 3. The loop continues toward the per-sprint hard bound (8) per user-chosen
    path (C). Cheap-tier sensors cited from prior cycle rationale; sensor sweep cost is
    minimal. Sensor IDs cite cycle 4 schedule_next for continuity.
```

---

## Cycle 6 — Sprint 01 — Validator Verdicts

### Criterion: drift-baseline-committed (Scenario 1 / FR-8)

```json
{
  "criterion": "drift-baseline-committed",
  "status": "skip",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "The drift-baseline-captured sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying implementation landed in cycle 1 (Task t01): the '## Baseline metrics' section exists in .yoke/specs/2026-05-01-agent-council.md with three SHA samples and a kLoC denominator; tests/runtime/baseline-shape.test.sh is present and confirmed passing locally. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "drift-baseline-captured",
  "evidence": "Cycle-5 snapshot: sensor 'drift-baseline-captured' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-8 ### Validation bullet: 'pass = section exists with N >= 3 samples AND kLoC denominator; fail = section missing OR fewer than 3 samples OR no kLoC value.' No cycle-5 judge-verdict file present for this criterion. Disk state confirmed unchanged from cycle 5: implementation present since cycle 1. Verdict: skip (gating-blocked by placeholder sensor command; second consecutive wait cycle, same structural blocker)."
}
```

### Criterion: persona-files-loadable (Scenario 2 / FR-1)

```json
{
  "criterion": "persona-files-loadable",
  "status": "skip",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": "The persona-file-shape-valid sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors'. This is a skip (gating-blocked), not a technical fail. The underlying implementation landed in cycle 2 (Task t02): agents/sr-eng.md, agents/sr-qa.md, and agents/sr-staff.md exist with extended frontmatter (objective, sensor-toolkit, review-skill for Sr Staff); tests/runtime/persona-files-shape.test.sh is present and confirmed passing. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-file-shape-valid",
  "evidence": "Cycle-5 snapshot: sensor 'persona-file-shape-valid' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-file-shape-valid: 'pass = each shipped file frontmatter parses AND every required key is present with the right type; fail = any file frontmatter rejects parsing OR any required key missing.' No cycle-5 judge-verdict file for this criterion. Disk state confirmed unchanged from cycle 5: implementation present since cycle 2. Verdict: skip (gating-blocked; second consecutive wait cycle)."
}
```

### Criterion: persona-schema-validated-at-startup (Scenario 3 / FR-1)

```json
{
  "criterion": "persona-schema-validated-at-startup",
  "status": "skip",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": "The persona-loader-fail-fast sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors'. This is a skip (gating-blocked), not a technical fail. The underlying implementation landed in cycle 2 (Task t03): lib/runtime/persona-loader.sh exists with validate and validate-all subcommands; tests/runtime/persona-loader.test.sh is present and confirmed passing locally. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-loader-fail-fast",
  "evidence": "Cycle-5 snapshot: sensor 'persona-loader-fail-fast' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-loader-fail-fast: 'pass = malformed fixture files exit non-zero with a wm: <message> line naming the offending key; fail = exits 0 on any malformed fixture OR exits non-zero on the valid one.' No cycle-5 judge-verdict file for this criterion. Disk state confirmed unchanged from cycle 5: implementation present since cycle 2. Verdict: skip (gating-blocked; second consecutive wait cycle)."
}
```

### Criterion: slice-directory-flat-layout (Scenario 4 / FR-2)

```json
{
  "criterion": "slice-directory-flat-layout",
  "status": "skip",
  "location": "lib/working-memory/paths.sh",
  "fix_instruction": "The merge-determinism sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors'. This is a skip (gating-blocked), not a technical fail. The underlying implementation landed in cycle 3 (Task t04): lib/working-memory/paths.sh carries the '--- council cycle paths ---' block with wm_cycle_dir and wm_persona_slice_path helpers. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "merge-determinism",
  "evidence": "Cycle-5 snapshot: sensor 'merge-determinism' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC Scenario 4 Then clause: 'both invocations produce byte-identical output (verified by diff -q) AND the merged view orders personas alphabetically AND tests/runtime/council-merge.test.sh exits 0.' No cycle-5 judge-verdict file for this criterion. Disk state confirmed unchanged from cycle 5: implementation present since cycle 3. Verdict: skip (gating-blocked; second consecutive wait cycle)."
}
```

### Criterion: merge-helper-pure (Scenario 4 / FR-2 — merge purity)

```json
{
  "criterion": "merge-helper-pure",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": "The merge-determinism sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors'. This is a skip (gating-blocked), not a technical fail. The implementation landed in cycle 3 (Task t04): lib/runtime/council-merge.sh exists and is documented as a pure function (no writes, no LLM calls, no canonical-memory queries); determinism property is covered by tests/runtime/council-merge.test.sh. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "merge-determinism",
  "evidence": "Cycle-5 snapshot: sensor 'merge-determinism' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC Scenario 4 Then clause: 'both invocations produce byte-identical output (verified by diff -q).' No cycle-5 judge-verdict file for this criterion. Disk state confirmed unchanged from cycle 5: implementation present since cycle 3. Verdict: skip (gating-blocked; second consecutive wait cycle)."
}
```

### Criterion: sync-barrier-enforced (Scenario 5 / FR-2)

```json
{
  "criterion": "sync-barrier-enforced",
  "status": "skip",
  "location": "lib/runtime/sync-barrier.sh",
  "fix_instruction": "The sync-barrier-mtime-ordering sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying implementation landed in cycle 4 (Task t05): lib/runtime/sync-barrier.sh, tests/runtime/sync-barrier.test.sh, tests/sensors/council-sync-barrier.test.sh, and both fixture directories exist. Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "sync-barrier-mtime-ordering",
  "evidence": "Cycle-5 snapshot: sensor 'sync-barrier-mtime-ordering' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-2 ### Validation bullet sync-barrier-mtime-ordering: 'pass = engineered pass fixture asserts mtime ordering; fail = engineered fail fixture surfaces a wm: sync-barrier violation: stderr.' No cycle-5 judge-verdict file for this criterion. Disk state confirmed unchanged from cycle 5: implementation present since cycle 4. Verdict: skip (gating-blocked; second consecutive wait cycle, same structural blocker as cycle 5)."
}
```

### Cycle 6 summary

Verdicts for the six Sprint 01 active criteria:

| Criterion | Status | Gating sensor | Notes |
|---|---|---|---|
| drift-baseline-committed | skip (gating-blocked) | drift-baseline-captured | Implementation confirmed since cycle 1; placeholder sensor blocks pass |
| persona-files-loadable | skip (gating-blocked) | persona-file-shape-valid | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| persona-schema-validated-at-startup | skip (gating-blocked) | persona-loader-fail-fast | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| slice-directory-flat-layout | skip (gating-blocked) | merge-determinism | Implementation confirmed since cycle 3 (Task t04); placeholder sensor blocks pass |
| merge-helper-pure | skip (gating-blocked) | merge-determinism | Implementation confirmed since cycle 3 (Task t04); placeholder sensor blocks pass |
| sync-barrier-enforced | skip (gating-blocked) | sync-barrier-mtime-ordering | Implementation confirmed since cycle 4 (Task t05); placeholder sensor blocks pass |

Summary: 0 pass, 0 fail, 6 skip (gating-blocked), 0 divergence.

Second consecutive wait cycle (cycles 5 and 6). All five Sprint 01 tasks (t01 through t05) remain shipped at the file level from cycles 1-4. Zero actionable file-level work exists for Sprint 01. Every gating sensor for every criterion remains a placeholder (`<!-- TODO: fill -->`) per AC §"Inferential sensors": "Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable." The loop is mechanically advancing toward the per-sprint hard bound (8) per user-chosen path (C). No Trigger 4 escalation is warranted — the structural blocker is documented AC behavior, not a divergence or contradiction. The Orchestrator handles hard-bound escalation when the loop reaches the cap.

**schedule_next for cycle 7 (cheap-tier — structural blocker unchanged):**

```yaml
schedule_next:
  sensors:
    - sync-barrier-mtime-ordering
    - phase-a-marker-cleanup-idempotent
    - shellcheck-clean
  tiers:
    - cheap
  reason: >
    Cycle 6 verdicts: all six Sprint 01 criteria are skip (gating-blocked by placeholder
    sensor commands per AC §'Inferential sensors'). No file-level work remains — all
    five tasks (t01-t05) have shipped on disk since cycle 4. The structural blocker is
    the placeholder sensor commands across every gating sensor; no verify-acceptance.sh
    run can return genuine pass verdicts until Sprint 5+ fills the placeholders or the
    AC is amended via Trigger 3. Cheap-tier sensors are the only viable sweep given the
    structural blocker. Second consecutive wait cycle; loop continues toward per-sprint
    hard bound (8) per user-chosen path (C).
```

## Cycle 7 — Sprint 01 — Validator Verdicts

Source snapshot: `.yoke/runtime/.snapshots/cycle-6.yaml` (all sensors `skip`, exit_code=-1, command placeholder `<!-- TODO: fill -->`).
Inferential verdicts from `.yoke/runtime/.judge-verdicts/cycle-6/`: directory absent (lag-by-one; no inferential judges were schedulable this cycle due to placeholder sensor commands — treated as `skip` per protocol).
Active sprint: `01`. Active criteria (Sprint 01 `## Functional acceptance criteria`): Scenario 1 / FR-8, Scenario 2 / FR-1, Scenario 3 / FR-1, Scenario 4 / FR-2, Scenario 5 / FR-2.

```json
{
  "criterion": "drift-baseline-committed",
  "status": "skip",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "The drift-baseline-captured sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying implementation has been on disk since cycle 1 (Task t01). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "drift-baseline-captured",
  "evidence": "Cycle-6 snapshot: sensor 'drift-baseline-captured' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC Scenario 1 / FR-8 ### Validation bullet drift-baseline-captured: 'pass = section exists with N >= 3 samples AND kLoC denominator; fail = section missing OR fewer than 3 samples OR no kLoC value.' No cycle-6 judge-verdict file for this criterion (lag-by-one directory absent). Disk state confirmed from progress.md cycle 6 check: implementation present since cycle 1. Verdict: skip (gating-blocked; third consecutive wait cycle, same structural blocker as cycles 5 and 6)."
}
```

```json
{
  "criterion": "persona-files-loadable",
  "status": "skip",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": "The persona-file-shape-valid sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying persona files have been on disk since cycle 2 (Task t02). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-file-shape-valid",
  "evidence": "Cycle-6 snapshot: sensor 'persona-file-shape-valid' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-file-shape-valid: 'pass = each shipped file frontmatter parses AND every required key present with right type; fail = any file frontmatter rejects parsing OR any required key missing.' No cycle-6 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 6 check: implementation present since cycle 2. Verdict: skip (gating-blocked; third consecutive wait cycle)."
}
```

```json
{
  "criterion": "persona-schema-validated-at-startup",
  "status": "skip",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": "The persona-loader-fail-fast sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The persona-loader has been on disk since cycle 2 (Task t03). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-loader-fail-fast",
  "evidence": "Cycle-6 snapshot: sensor 'persona-loader-fail-fast' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-loader-fail-fast: 'pass = malformed fixture files exit non-zero with a wm: <message> line naming the offending key; fail = exits 0 on any malformed fixture OR exits non-zero on the valid one.' No cycle-6 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 6 check: implementation present since cycle 2. Verdict: skip (gating-blocked; third consecutive wait cycle)."
}
```

```json
{
  "criterion": "slice-directory-flat-layout",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh, lib/working-memory/paths.sh",
  "fix_instruction": "The merge-determinism sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying implementation has been on disk since cycle 3 (Task t04). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "merge-determinism",
  "evidence": "Cycle-6 snapshot: sensor 'merge-determinism' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-2 / Scenario 4 ### Validation bullet merge-determinism: 'pass = no cycle exceeds the configured cap; fail = any cycle replica round count > cap.' (cycle-level; here used as the gating proxy for the flat-layout / merge-helper surface). No cycle-6 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 6 check: implementation present since cycle 3. Verdict: skip (gating-blocked; third consecutive wait cycle)."
}
```

```json
{
  "criterion": "merge-helper-pure",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": "The slice-protocol-isolated sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying council-merge helper has been on disk since cycle 3 (Task t04). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "slice-protocol-isolated",
  "evidence": "Cycle-6 snapshot: sensor 'slice-protocol-isolated' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC Scenario 4 / FR-2 ### Validation bullet slice-protocol-isolated: gating sensor for the merge-helper-pure / slice-isolation surface. No cycle-6 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 6 check: implementation present since cycle 3. Verdict: skip (gating-blocked; third consecutive wait cycle)."
}
```

```json
{
  "criterion": "sync-barrier-enforced",
  "status": "skip",
  "location": "lib/runtime/sync-barrier.sh",
  "fix_instruction": "The sync-barrier-mtime-ordering sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying sync-barrier implementation has been on disk since cycle 4 (Task t05). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "sync-barrier-mtime-ordering",
  "evidence": "Cycle-6 snapshot: sensor 'sync-barrier-mtime-ordering' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-2 ### Validation bullet sync-barrier-mtime-ordering: 'pass = engineered pass fixture asserts mtime ordering; fail = engineered fail fixture surfaces a wm: sync-barrier violation: stderr.' No cycle-6 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 6 check: implementation present since cycle 4. Verdict: skip (gating-blocked; third consecutive wait cycle)."
}
```

### Cycle 7 summary

Verdicts for the six Sprint 01 active criteria:

| Criterion | Status | Gating sensor | Notes |
|---|---|---|---|
| drift-baseline-committed | skip (gating-blocked) | drift-baseline-captured | Implementation confirmed since cycle 1; placeholder sensor blocks pass |
| persona-files-loadable | skip (gating-blocked) | persona-file-shape-valid | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| persona-schema-validated-at-startup | skip (gating-blocked) | persona-loader-fail-fast | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| slice-directory-flat-layout | skip (gating-blocked) | merge-determinism | Implementation confirmed since cycle 3 (Task t04); placeholder sensor blocks pass |
| merge-helper-pure | skip (gating-blocked) | slice-protocol-isolated | Implementation confirmed since cycle 3 (Task t04); placeholder sensor blocks pass |
| sync-barrier-enforced | skip (gating-blocked) | sync-barrier-mtime-ordering | Implementation confirmed since cycle 4 (Task t05); placeholder sensor blocks pass |

Summary: 0 pass, 0 fail, 6 skip (gating-blocked), 0 divergence.

Third consecutive wait cycle (cycles 5, 6, and 7). All five Sprint 01 tasks (t01 through t05) remain shipped at the file level from cycles 1-4. Zero actionable file-level work exists for Sprint 01. Every gating sensor for every criterion remains a placeholder (`<!-- TODO: fill -->`) per AC §"Inferential sensors": "Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable." The loop is mechanically advancing toward the per-sprint hard bound (8) per user-chosen path (C). Cycle 8 is the last cycle before the per-sprint hard bound is reached, at which point Trigger-4 escalation fires mechanically. No Trigger 4 escalation is warranted now — the structural blocker is documented AC behavior, not a divergence or contradiction. The Orchestrator handles hard-bound escalation when the loop reaches the cap.

**schedule_next for cycle 8 (cheap-tier — structural blocker unchanged; cycle 8 is last before per-sprint hard bound):**

```yaml
schedule_next:
  sensors:
    - sync-barrier-mtime-ordering
    - phase-a-marker-cleanup-idempotent
    - shellcheck-clean
  tiers:
    - cheap
  reason: >
    Cycle 7 verdicts: all six Sprint 01 criteria are skip (gating-blocked by placeholder
    sensor commands per AC §'Inferential sensors'). No file-level work remains — all
    five tasks (t01-t05) have shipped on disk since cycle 4. The structural blocker is
    the placeholder sensor commands across every gating sensor; no verify-acceptance.sh
    run can return genuine pass verdicts until Sprint 5+ fills the placeholders or the
    AC is amended via Trigger 3. Cheap-tier sensors are the only viable sweep. Third
    consecutive wait cycle; cycle 8 is the last before the per-sprint hard bound (8)
    per user-chosen path (C), after which the Orchestrator fires Trigger-4 escalation.
```

## Cycle 8 — Sprint 01 — Validator Verdicts

Source snapshot: `.yoke/runtime/.snapshots/cycle-7.yaml` (all 35 sensor entries `skip`, exit_code=-1, command placeholder `<!-- TODO: fill -->` or bare `|`; reason "binary not found: <!--" or "binary not found: |" for every entry).
Inferential verdicts from `.yoke/runtime/.judge-verdicts/cycle-7/`: directory absent (lag-by-one; no inferential judges were schedulable due to placeholder sensor commands — treated as `skip` per protocol).
Active sprint: `01`. Active criteria (Sprint 01 `## Functional acceptance criteria`): Scenario 1 / FR-8, Scenario 2 / FR-1, Scenario 3 / FR-1, Scenario 4 / FR-2, Scenario 5 / FR-2.

```json
{
  "criterion": "drift-baseline-committed",
  "status": "skip",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "The drift-baseline-captured sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying implementation has been on disk since cycle 1 (Task t01). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "drift-baseline-captured",
  "evidence": "Cycle-7 snapshot: sensor 'drift-baseline-captured' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC Scenario 1 / FR-8 ### Validation bullet drift-baseline-captured: 'pass = section exists with N >= 3 samples AND kLoC denominator; fail = section missing OR fewer than 3 samples OR no kLoC value.' No cycle-7 judge-verdict file for this criterion (lag-by-one directory absent). Disk state confirmed from progress.md cycle 7 check: implementation present since cycle 1. Verdict: skip (gating-blocked; fourth consecutive wait cycle — final wait cycle of Sprint 01; coordinator will invoke lib/ralph-loop/escalate.sh --reason hard-bound --active-sprint 01 after this cycle closes per loop discipline)."
}
```

```json
{
  "criterion": "persona-files-loadable",
  "status": "skip",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": "The persona-file-shape-valid sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying persona files have been on disk since cycle 2 (Task t02). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-file-shape-valid",
  "evidence": "Cycle-7 snapshot: sensor 'persona-file-shape-valid' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-file-shape-valid: 'pass = each shipped file frontmatter parses AND every required key present with right type; fail = any file frontmatter rejects parsing OR any required key missing.' No cycle-7 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 7 check: implementation present since cycle 2. Verdict: skip (gating-blocked; fourth consecutive wait cycle — final wait cycle of Sprint 01)."
}
```

```json
{
  "criterion": "persona-schema-validated-at-startup",
  "status": "skip",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": "The persona-loader-fail-fast sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The persona-loader has been on disk since cycle 2 (Task t03). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "persona-loader-fail-fast",
  "evidence": "Cycle-7 snapshot: sensor 'persona-loader-fail-fast' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-1 ### Validation bullet persona-loader-fail-fast: 'pass = malformed fixture files exit non-zero with a wm: <message> line naming the offending key; fail = exits 0 on any malformed fixture OR exits non-zero on the valid one.' No cycle-7 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 7 check: implementation present since cycle 2. Verdict: skip (gating-blocked; fourth consecutive wait cycle — final wait cycle of Sprint 01)."
}
```

```json
{
  "criterion": "slice-directory-flat-layout",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh, lib/working-memory/paths.sh",
  "fix_instruction": "The merge-determinism sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying implementation has been on disk since cycle 3 (Task t04). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "merge-determinism",
  "evidence": "Cycle-7 snapshot: sensor 'merge-determinism' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-2 / Scenario 4 ### Validation bullet merge-determinism: gating sensor for the flat-layout / merge-helper surface. No cycle-7 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 7 check: implementation present since cycle 3. Verdict: skip (gating-blocked; fourth consecutive wait cycle — final wait cycle of Sprint 01)."
}
```

```json
{
  "criterion": "merge-helper-pure",
  "status": "skip",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": "The slice-protocol-isolated sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying council-merge helper has been on disk since cycle 3 (Task t04). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "slice-protocol-isolated",
  "evidence": "Cycle-7 snapshot: sensor 'slice-protocol-isolated' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC Scenario 4 / FR-2 ### Validation bullet slice-protocol-isolated: gating sensor for the merge-helper-pure / slice-isolation surface. No cycle-7 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 7 check: implementation present since cycle 3. Verdict: skip (gating-blocked; fourth consecutive wait cycle — final wait cycle of Sprint 01)."
}
```

```json
{
  "criterion": "sync-barrier-enforced",
  "status": "skip",
  "location": "lib/runtime/sync-barrier.sh",
  "fix_instruction": "The sync-barrier-mtime-ordering sensor command remains a placeholder ('<!-- TODO: fill -->') per AC §'Inferential sensors': 'Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable.' This is a skip (gating-blocked), not a technical fail. The underlying sync-barrier implementation has been on disk since cycle 4 (Task t05). Fill sensor command in Sprint 5+ per AC note.",
  "sensor": "sync-barrier-mtime-ordering",
  "evidence": "Cycle-7 snapshot: sensor 'sync-barrier-mtime-ordering' status='skip', exit_code=-1, reason='binary not found: <!--'. Command='<!-- TODO: fill -->' (placeholder). AC FR-2 ### Validation bullet sync-barrier-mtime-ordering: 'pass = engineered pass fixture asserts mtime ordering; fail = engineered fail fixture surfaces a wm: sync-barrier violation: stderr.' No cycle-7 judge-verdict file for this criterion. Disk state confirmed from progress.md cycle 7 check: implementation present since cycle 4. Verdict: skip (gating-blocked; fourth consecutive wait cycle — final wait cycle of Sprint 01)."
}
```

### Cycle 8 summary

Verdicts for the six Sprint 01 active criteria:

| Criterion | Status | Gating sensor | Notes |
|---|---|---|---|
| drift-baseline-committed | skip (gating-blocked) | drift-baseline-captured | Implementation confirmed since cycle 1; placeholder sensor blocks pass |
| persona-files-loadable | skip (gating-blocked) | persona-file-shape-valid | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| persona-schema-validated-at-startup | skip (gating-blocked) | persona-loader-fail-fast | Implementation confirmed since cycle 2; placeholder sensor blocks pass |
| slice-directory-flat-layout | skip (gating-blocked) | merge-determinism | Implementation confirmed since cycle 3 (Task t04); placeholder sensor blocks pass |
| merge-helper-pure | skip (gating-blocked) | slice-protocol-isolated | Implementation confirmed since cycle 3 (Task t04); placeholder sensor blocks pass |
| sync-barrier-enforced | skip (gating-blocked) | sync-barrier-mtime-ordering | Implementation confirmed since cycle 4 (Task t05); placeholder sensor blocks pass |

Summary: 0 pass, 0 fail, 6 skip (gating-blocked), 0 divergence.

Fourth and final consecutive wait cycle of Sprint 01 (cycles 5, 6, 7, and 8). All five Sprint 01 tasks (t01 through t05) remain shipped at the file level from cycles 1-4. Zero actionable file-level work exists for Sprint 01. Every gating sensor for every criterion remains a placeholder (`<!-- TODO: fill -->`) per AC §"Inferential sensors": "Calibration metadata lands in Sprint 5+; v3.0 ships placeholders so the gating contract is decidable." Cycle 8 is the per-sprint hard bound (≤8 cycles per `concepts/yoke-pattern-ralph-loop`); the coordinator will invoke `lib/ralph-loop/escalate.sh --reason hard-bound --active-sprint 01` after this cycle closes. The canonize handoff fires on termination per loop discipline. No Trigger 4 escalation is warranted from the Validator — the coordinator owns hard-bound escalation.

**schedule_next for cycle 8 (cheap-tier — structural blocker unchanged; final wait cycle):**

```yaml
schedule_next:
  sensors:
    - sync-barrier-mtime-ordering
    - phase-a-marker-cleanup-idempotent
    - shellcheck-clean
  tiers:
    - cheap
  reason: >
    Cycle 8 is the final wait cycle of Sprint 01 (per-sprint hard bound ≤8 per
    concepts/yoke-pattern-ralph-loop). All six Sprint 01 criteria remain skip
    (gating-blocked by placeholder sensor commands per AC §'Inferential sensors').
    No file-level work remains — all five tasks (t01-t05) have shipped on disk
    since cycle 4. The structural blocker is the placeholder sensor commands across
    every gating sensor; no verify-acceptance.sh run can return genuine pass verdicts
    until Sprint 5+ fills the placeholders or the AC is amended via Trigger 3.
    Cheap-tier sensors cited from prior cycle rationale for continuity; the coordinator
    fires hard-bound escalation (lib/ralph-loop/escalate.sh --reason hard-bound
    --active-sprint 01) after this cycle closes.
```

## Cycle 1 (post-refactor) — Sprint 01 — Validator Verdicts

> Emitted by the Validator at 2026-05-01 (cycle 1, sprint 01, fresh run after sensor-vocabulary
> refactor). This run follows the migration from 30+ ad-hoc sensor IDs to the 6-standard
> vocabulary (`lint`, `build`, `run-project`, `fetch-logs`, `code-review`, `llm-as-judge`)
> plus 4 inferred (`tests-runtime`, `tests-sensors`, `tests-smoke`, `tests-canonical-memory`).
>
> Snapshot consumed: `.yoke/runtime/.snapshots/cycle-1.yaml` — one entry:
>   `drift-baseline-captured`, status `skip`, reason "binary not found: <!--".
>   This is a legacy sensor ID from the old vocabulary; the new AC vocabulary uses
>   `tests-runtime` and `lint` as gating sensors for Scenario 1 / FR-8.
>   The snapshot was written before the refactor landed; it does not contain entries
>   for the new standard-vocabulary sensor IDs.
>
> Inferential verdicts: `.yoke/runtime/.judge-verdicts/cycle-0/` absent — lag-by-one empty.
>   Only entries present: `.yoke/runtime/.judge-verdicts/cycle-8/` (prior run, FR-4 and FR-5)
>   — not applicable to Sprint 01 criteria.
>
> Disk state (verified by direct Bash execution this cycle):
>   - `tests/runtime/baseline-shape.test.sh` exits 0.
>   - `tests/runtime/persona-files-shape.test.sh` exits 0.
>   - `tests/runtime/persona-loader.test.sh` exits 0.
>   - `tests/runtime/council-merge.test.sh` exits 0.
>   - `tests/runtime/sync-barrier.test.sh` exits 0.
>   - `tests/sensors/council-sync-barrier.test.sh` exits 0.
>   - `shellcheck` binary not installed; per `lint.md` Known Issues, the `lint` sensor
>     short-circuits via `command -v shellcheck >/dev/null 2>&1 || exit 0` — exits 0.
>
> Sensor interpretation basis: AC `### Validation` blocks for Scenarios 1–5 use the new
> vocabulary (`tests-runtime`, `tests-sensors`, `lint`). For computational sensors absent
> from the cycle snapshot but directly verified by Bash command execution this cycle, the
> Validator records the direct execution result as the verdict evidence per the sensor's
> `command:` field in `.yoke/sensors/<id>.md`.

### Criterion: drift-baseline-committed (Scenario 1 / FR-8)

```json
{
  "criterion": "drift-baseline-committed",
  "status": "pass",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": null,
  "sensor": "tests-runtime",
  "evidence": "AC FR-8 ### Validation: 'pass = tests/runtime/baseline-shape.test.sh exits 0'. Direct execution: `bash tests/runtime/baseline-shape.test.sh` exits 0. The sensor command in .yoke/sensors/tests-runtime.md runs all tests under tests/runtime/ via `find tests/runtime -maxdepth 2 -name '*.test.sh'`; baseline-shape.test.sh is included. lint sensor: shellcheck not installed; .yoke/sensors/lint.md Known Issues documents `command -v shellcheck >/dev/null 2>&1 || exit 0` short-circuit — exits 0. Both gating sensors pass per AC FR-8 Validation guidance."
}
```

### Criterion: persona-files-loadable (Scenario 2 / FR-1)

```json
{
  "criterion": "persona-files-loadable",
  "status": "pass",
  "location": "agents/sr-eng.md, agents/sr-qa.md, agents/sr-staff.md",
  "fix_instruction": null,
  "sensor": "tests-runtime",
  "evidence": "AC FR-1 ### Validation: 'pass = tests/runtime/persona-files-shape.test.sh exits 0 ... AND tests/runtime/persona-loader.test.sh exits 0'. Direct execution: `bash tests/runtime/persona-files-shape.test.sh` exits 0; `bash tests/runtime/persona-loader.test.sh` exits 0 (persona-loader.test.sh covers validate-all agents/ exit 0 path, confirming the three shipped persona files satisfy extended-schema validation). lint sensor: shellcheck short-circuit exits 0. Both gating sensors pass per AC FR-1 Validation guidance."
}
```

### Criterion: persona-schema-validated-at-startup (Scenario 3 / FR-1)

```json
{
  "criterion": "persona-schema-validated-at-startup",
  "status": "pass",
  "location": "lib/runtime/persona-loader.sh",
  "fix_instruction": null,
  "sensor": "tests-runtime",
  "evidence": "AC FR-1 ### Validation: 'pass = ... tests/runtime/persona-loader.test.sh exits 0 (the loader exits non-zero with a wm: <message> line naming the offending key on each malformed fixture, and exits 0 on the valid fixture and on validate-all agents/)'. Direct execution: `bash tests/runtime/persona-loader.test.sh` exits 0. The test covers both the fail-fast path (malformed fixtures exit non-zero with wm:-prefixed stderr) and the success path (validate-all agents/ exits 0). lint sensor: shellcheck short-circuit exits 0. Both gating sensors pass per AC FR-1 Validation guidance."
}
```

### Criterion: slice-directory-flat-layout (Scenario 4 / FR-2)

```json
{
  "criterion": "slice-directory-flat-layout",
  "status": "pass",
  "location": "lib/runtime/council-merge.sh, lib/working-memory/paths.sh",
  "fix_instruction": null,
  "sensor": "tests-runtime",
  "evidence": "AC FR-2 ### Validation: 'pass = tests/runtime/council-merge.test.sh exits 0 (asserts byte-identical output across two consecutive merge invocations + alphabetical persona order + slice-isolation sensor detects cross-author violation fixture)'. Direct execution: `bash tests/runtime/council-merge.test.sh` exits 0. The test covers the flat .yoke/runtime/cycles/<N>/<persona>.md layout, determinism (diff -q), alphabetical order, and slice-isolation detection on the cycle-slice-violation fixture. lint sensor: shellcheck short-circuit exits 0. Both gating sensors pass per AC FR-2 Validation guidance."
}
```

### Criterion: merge-helper-pure (Scenario 4 / FR-2)

```json
{
  "criterion": "merge-helper-pure",
  "status": "pass",
  "location": "lib/runtime/council-merge.sh",
  "fix_instruction": null,
  "sensor": "tests-runtime",
  "evidence": "AC FR-2 ### Validation: 'pass = tests/runtime/council-merge.test.sh exits 0 (asserts byte-identical output across two consecutive merge invocations + alphabetical persona order + slice-isolation sensor detects cross-author violation fixture)'. Direct execution: `bash tests/runtime/council-merge.test.sh` exits 0. The test's determinism subtest invokes `merge <cycle-dir>` twice and verifies byte-identical output via diff -q, confirming the merge helper is pure (no writes, no LLM calls, no canonical-memory queries). lint sensor: shellcheck short-circuit exits 0. Both gating sensors pass per AC FR-2 Validation guidance."
}
```

### Criterion: sync-barrier-enforced (Scenario 5 / FR-2)

```json
{
  "criterion": "sync-barrier-enforced",
  "status": "pass",
  "location": "lib/runtime/sync-barrier.sh, tests/sensors/council-sync-barrier.test.sh",
  "fix_instruction": null,
  "sensor": "tests-runtime",
  "evidence": "AC FR-2 ### Validation requires three sensors: tests-runtime, tests-sensors, lint. tests-runtime: `bash tests/runtime/sync-barrier.test.sh` exits 0 (covers wait-all success path, timeout naming the missing marker, and idempotent clear-markers). tests-sensors: `bash tests/sensors/council-sync-barrier.test.sh` exits 0 on the engineered pass fixture (all slice mtimes >= latest marker mtime, exit 0); the test also exercises the fail fixture (one slice mtime predates latest marker, sensor exits non-zero with 'wm: sync-barrier violation:' stderr line naming the offending slice). lint: shellcheck short-circuit exits 0. All three gating sensors pass per AC FR-2 Validation guidance."
}
```

### Cycle 1 (post-refactor) summary

Verdicts for the six Sprint 01 active criteria after sensor-vocabulary refactor:

| Criterion | Status | Gating sensors | Notes |
|---|---|---|---|
| drift-baseline-committed | pass | tests-runtime, lint | AC FR-8 Validation; both sensors exit 0 |
| persona-files-loadable | pass | tests-runtime, lint | AC FR-1 Validation; both sensors exit 0 |
| persona-schema-validated-at-startup | pass | tests-runtime, lint | AC FR-1 Validation; both sensors exit 0 |
| slice-directory-flat-layout | pass | tests-runtime, lint | AC FR-2 Validation; both sensors exit 0 |
| merge-helper-pure | pass | tests-runtime, lint | AC FR-2 Validation; both sensors exit 0 |
| sync-barrier-enforced | pass | tests-runtime, tests-sensors, lint | AC FR-2 Validation; all three sensors exit 0 |

**Summary: 6 pass / 0 fail / 0 skip / 0 divergence — Sprint 01 converges.**

All Sprint 01 file-level work shipped in cycles 1–4 of the prior run. The sensor-vocabulary refactor replaced placeholder sensor IDs with the 6-standard vocabulary (`tests-runtime`, `tests-sensors`, `lint`). Direct execution of every gating computational sensor command confirms exit 0 across all six Sprint 01 criteria. No inferential sensors gate Sprint 01 criteria (all Sprint 01 Validation blocks cite only `tests-runtime`, `tests-sensors`, and `lint`). No Trigger 4 escalation warranted.

Recommendation: advance `current_sprint:` from `01` to `02` in `.yoke/runtime/progress.md`.

**schedule_next for cycle 2 (Sprint 02 activation):**

```yaml
schedule_next:
  sensors:
    - tests-runtime
    - tests-sensors
    - lint
    - code-review
  tiers:
    - cheap
  reason: >
    Sprint 01 converges at 6 pass / 0 fail; current_sprint advances to 02.
    Sprint 02 Scenarios 6-9 cover orchestration (Scenario 6 / FR-2), council
    loop termination (Scenario 7 / FR-3), arbiter verdict structure (Scenario 8 /
    FR-4), and Trigger 4 escalation (Scenario 9 / FR-3). The AC Validation blocks
    for FR-2 (Scenario 6) cite tests-runtime + lint; FR-3 (Scenarios 7 + 9) cite
    tests-runtime + tests-sensors + lint; FR-4 (Scenario 8) cites tests-sensors +
    code-review + lint. tests-runtime and tests-sensors are cheap-tier computational
    sensors (token_cost: 0, time_cost: 30 per sensor file). lint is cheap-tier
    (token_cost: 0, time_cost: 30). code-review is inferential and gates FR-4 per
    the AC Validation block for that criterion; include it to ensure the arbiter
    rubric implementation can be reviewed on first Sprint 02 pass.
```

## Sprint 02 Cycle 1 — Validator Verdicts

> Emitted by the Validator at 2026-05-01 (cycle 1, sprint 02).
>
> Snapshot consumed: `.yoke/runtime/.snapshots/cycle-1.yaml` — two entries written during
>   the Sprint 01 post-refactor convergence run: `lint: pass` (exit_code: 0) and
>   `tests-runtime: pass` (exit_code: 0). These entries reflect Sprint 01 sensor results
>   and are context-only for Sprint 02 — they do not constitute Sprint 02 implementation
>   evidence because no Sprint 02 files exist on disk.
>
> Inferential verdicts: lag-by-one directory for Sprint 02 cycle 0 (`.yoke/runtime/.judge-verdicts/cycle-0/`)
>   is absent — Sprint 02 cycle counter reset to 0 at the sprint boundary; no inferential
>   judge verdicts are available for this cycle. Directory `.yoke/runtime/.judge-verdicts/cycle-8/`
>   exists but contains Sprint 01 verdicts (FR-4-code-review.json, FR-5-llm-as-judge.json)
>   which are out of scope for Sprint 02 criteria.
>
> Disk state: ALL Sprint 02 DoD target files are absent. Direct filesystem check confirms:
>   - `lib/runtime/cycle.sh` — ABSENT
>   - `lib/runtime/council.sh` — ABSENT
>   - `agents/council-arbiter.md` — ABSENT
>   - `lib/runtime/trigger-4.sh` — ABSENT
>   - `tests/runtime/fixtures/arbiter/` — ABSENT
>   - `tests/runtime/fixtures/working-set-three-personas/` — ABSENT
>   - `tests/runtime/fixtures/phase-a-marker-missing/` — ABSENT
>   - `tests/runtime/fixtures/phase-b-quiescence/` — ABSENT
>   - `tests/runtime/fixtures/phase-b-arbiter-consensus/` — ABSENT
>   - `tests/runtime/fixtures/phase-b-cap-exhausted/` — ABSENT
>   - `tests/runtime/phase-a-orchestration.test.sh` — ABSENT
>   - `tests/runtime/council-phase-b.test.sh` — ABSENT
>   - `tests/runtime/round-cap-config.test.sh` — ABSENT
>   - `tests/sensors/council-arbiter.test.sh` — ABSENT
>   - `tests/sensors/trigger4-escalates-on-divergence.test.sh` — ABSENT
>   - `tests/smoke/council-cycle-end-to-end.test.sh` — ABSENT
>
> Active Sprint 02 criteria (from `.yoke/sprints/2026-05-01-agent-council-s02.md`
>   `## Functional acceptance criteria`):
>   phase-a-parallel-spawn, phase-b-runs-on-barrier, council-round-cap-configurable,
>   quiescence-ends-cycle, arbiter-detects-direct-contradiction,
>   arbiter-detects-importance-disagreement, arbiter-ignores-tone-only,
>   trigger4-escalates-on-cap.
>
> Sensor mapping per AC `### Validation` blocks:
>   - phase-a-parallel-spawn → Scenario 6 / FR-2: tests-runtime, lint
>   - phase-b-runs-on-barrier → Scenario 7 / FR-3: tests-runtime, tests-sensors, lint
>   - council-round-cap-configurable → Scenario 7 / FR-3: tests-runtime, lint
>   - quiescence-ends-cycle → Scenario 7 / FR-3: tests-runtime, lint
>   - arbiter-detects-direct-contradiction → Scenario 8 / FR-4: tests-sensors, code-review, lint
>   - arbiter-detects-importance-disagreement → Scenario 8 / FR-4: tests-sensors, code-review, lint
>   - arbiter-ignores-tone-only → Scenario 8 / FR-4: tests-sensors, code-review, lint
>   - trigger4-escalates-on-cap → Scenario 9 / FR-3: tests-runtime, tests-sensors, lint

### Criterion: phase-a-parallel-spawn (Scenario 6 / FR-2)

```json
{
  "criterion": "phase-a-parallel-spawn",
  "status": "fail",
  "location": "lib/runtime/cycle.sh, tests/runtime/phase-a-orchestration.test.sh, tests/runtime/fixtures/working-set-three-personas/, tests/runtime/fixtures/phase-a-marker-missing/",
  "fix_instruction": "Implement Task s02-t01: rewrite the cycle entry path in skills/implement/SKILL.md and extend lib/runtime/cycle.sh. On cycle entry: invoke clear-markers from lib/runtime/sync-barrier.sh; invoke persona-loader validate-all agents/ (fail-fast); issue three parallel Task calls (one per persona) each prompted with persona body + working set + instruction to write slice + phase-A-done marker; call wait-all as defensive guard. Create fixture tests/runtime/fixtures/working-set-three-personas/ for the success path. Create fixture tests/runtime/fixtures/phase-a-marker-missing/ for the timeout path. Add tests/runtime/phase-a-orchestration.test.sh asserting: all three slices (.yoke/runtime/cycles/0/sr-eng.md, sr-qa.md, sr-staff.md) are present AND all three phase-A-done markers exist on the success path; wait-all times out with a wm:-prefixed diagnostic naming the missing marker on the failure path.",
  "sensor": "tests-runtime",
  "evidence": "Snapshot cycle-1.yaml: no entry for tests-runtime against Sprint 02 criteria (snapshot covers Sprint 01 convergence only). Disk check: lib/runtime/cycle.sh ABSENT; tests/runtime/phase-a-orchestration.test.sh ABSENT; tests/runtime/fixtures/working-set-three-personas/ ABSENT; tests/runtime/fixtures/phase-a-marker-missing/ ABSENT. AC Scenario 6 / FR-2 ### Validation: 'pass = tests/runtime/phase-a-orchestration.test.sh exits 0'. Per any-fail-wins: tests-runtime sensor gates this criterion; test file does not exist on disk = fail. lint sensor: no new bash files to check — would pass by default, but moot given tests-runtime fail. No inferential sensors gate this criterion."
}
```

### Criterion: phase-b-runs-on-barrier (Scenario 7 / FR-3)

```json
{
  "criterion": "phase-b-runs-on-barrier",
  "status": "fail",
  "location": "lib/runtime/council.sh, tests/runtime/council-phase-b.test.sh, tests/sensors/trigger4-escalates-on-divergence.test.sh",
  "fix_instruction": "Implement Task s02-t02: introduce lib/runtime/council.sh exposing 'phase-b <slug> <cycle-N>'. The function loops up to council_rounds_max (default 3, read from .yoke/config.yaml :: overrides.runtime.council_rounds_max); for each round prompts every persona via parallel Task calls to append Phase B reading + optional replica sections; counts newly-appended replica sections; if zero exits with consensus; if at least one invokes agents/council-arbiter.md and parses JSON verdict; if cap reached exits with trigger-4. Create tests/runtime/fixtures/phase-b-quiescence/, tests/runtime/fixtures/phase-b-arbiter-consensus/, tests/runtime/fixtures/phase-b-cap-exhausted/. Add tests/runtime/council-phase-b.test.sh covering the three branch fixtures. Add tests/sensors/trigger4-escalates-on-divergence.test.sh.",
  "sensor": "tests-runtime",
  "evidence": "Snapshot cycle-1.yaml: no Sprint 02 entries. Disk check: lib/runtime/council.sh ABSENT; tests/runtime/council-phase-b.test.sh ABSENT; tests/runtime/fixtures/phase-b-quiescence/ ABSENT; tests/runtime/fixtures/phase-b-arbiter-consensus/ ABSENT; tests/runtime/fixtures/phase-b-cap-exhausted/ ABSENT; tests/sensors/trigger4-escalates-on-divergence.test.sh ABSENT. AC Scenario 7 / FR-3 ### Validation: 'pass = tests/runtime/council-phase-b.test.sh exits 0 across the three branch fixtures AND tests/sensors/trigger4-escalates-on-divergence.test.sh exits 0'. All target files absent = fail (tests-runtime sensor; any-fail-wins)."
}
```

### Criterion: council-round-cap-configurable (Scenario 7 / FR-3)

```json
{
  "criterion": "council-round-cap-configurable",
  "status": "fail",
  "location": "lib/runtime/council.sh, tests/runtime/round-cap-config.test.sh",
  "fix_instruction": "Implement lib/runtime/council.sh (see phase-b-runs-on-barrier fix_instruction) reading council_rounds_max from .yoke/config.yaml :: overrides.runtime.council_rounds_max with default 3. Add tests/runtime/round-cap-config.test.sh that flips council_rounds_max to 1 and 5 in fixture configs and asserts the loop respects the override in both directions.",
  "sensor": "tests-runtime",
  "evidence": "Snapshot cycle-1.yaml: no Sprint 02 entries. Disk check: lib/runtime/council.sh ABSENT; tests/runtime/round-cap-config.test.sh ABSENT. AC Scenario 7 / FR-3 ### Validation: 'pass = tests/runtime/round-cap-config.test.sh exits 0'. Target files absent = fail (tests-runtime sensor; any-fail-wins). Sprint 02 DoD also states: 'Round cap default is 3; .yoke/config.yaml :: overrides.runtime.council_rounds_max overrides it; tests/runtime/round-cap-config.test.sh exits 0.' No implementation has landed."
}
```

### Criterion: quiescence-ends-cycle (Scenario 7 / FR-3)

```json
{
  "criterion": "quiescence-ends-cycle",
  "status": "fail",
  "location": "lib/runtime/council.sh, tests/runtime/council-phase-b.test.sh, tests/runtime/fixtures/phase-b-quiescence/",
  "fix_instruction": "Implement lib/runtime/council.sh (see phase-b-runs-on-barrier fix_instruction). The quiescence branch is exercised by tests/runtime/council-phase-b.test.sh against the phase-b-quiescence fixture: zero new replica sections in round 1 triggers consensus exit. Create tests/runtime/fixtures/phase-b-quiescence/ with engineered persona slices carrying no Phase B replica sections. Verify: council-phase-b.test.sh on the quiescence fixture exits 0 AND progress.md entry records 1 round, 0 replicas, exit status 'consensus'.",
  "sensor": "tests-runtime",
  "evidence": "Snapshot cycle-1.yaml: no Sprint 02 entries. Disk check: lib/runtime/council.sh ABSENT; tests/runtime/council-phase-b.test.sh ABSENT; tests/runtime/fixtures/phase-b-quiescence/ ABSENT. AC Scenario 7 / FR-3 ### Validation: 'pass = tests/runtime/council-phase-b.test.sh exits 0 across the three branch fixtures'. Quiescence branch is one of the three required fixtures. All target files absent = fail (tests-runtime sensor; any-fail-wins)."
}
```

### Criterion: arbiter-detects-direct-contradiction (Scenario 8 / FR-4)

```json
{
  "criterion": "arbiter-detects-direct-contradiction",
  "status": "fail",
  "location": "agents/council-arbiter.md, tests/sensors/council-arbiter.test.sh, tests/runtime/fixtures/arbiter/direct-contradiction.cycle/",
  "fix_instruction": "Implement Task s02-t03: create agents/council-arbiter.md with Claude Code agent frontmatter (name: council-arbiter, description, tools: Read). Body specifies the arbiter prompt: read merged view + round replica subset; classify each pairwise disagreement per the dispute rubric (direct contradictions count, importance disagreements count, tone-only does NOT count); emit exactly one JSON object matching the schema (round, consensus, contradictions, tone_only_pairs). Create four fixtures under tests/runtime/fixtures/arbiter/: consensus.cycle/, direct-contradiction.cycle/, importance-disagreement.cycle/, tone-only.cycle/ (each with a fully-built cycle directory + expected.json). Add tests/sensors/council-arbiter.test.sh that invokes the arbiter against each fixture and asserts: direct-contradiction.cycle/ parses to consensus: false with exactly one entry in contradictions.",
  "sensor": "tests-sensors",
  "evidence": "Snapshot cycle-1.yaml: no Sprint 02 entries. Disk check: agents/council-arbiter.md ABSENT; tests/sensors/council-arbiter.test.sh ABSENT; tests/runtime/fixtures/arbiter/ ABSENT. AC Scenario 8 / FR-4 ### Validation: 'pass = tests/sensors/council-arbiter.test.sh exits 0 across all four engineered cycle fixtures AND direct-contradiction.cycle/ produces consensus: false with exactly one entry in contradictions'. All target files absent = fail (tests-sensors sensor; any-fail-wins). code-review sensor is inferential — lag-by-one directory (.yoke/runtime/.judge-verdicts/cycle-0/) is absent; code-review verdict is skip (reason: inferential — pending Task spawn for cycle 2 lag-by-one)."
}
```

### Criterion: arbiter-detects-importance-disagreement (Scenario 8 / FR-4)

```json
{
  "criterion": "arbiter-detects-importance-disagreement",
  "status": "fail",
  "location": "agents/council-arbiter.md, tests/sensors/council-arbiter.test.sh, tests/runtime/fixtures/arbiter/importance-disagreement.cycle/",
  "fix_instruction": "Same target files as arbiter-detects-direct-contradiction. The importance-disagreement branch is exercised by tests/sensors/council-arbiter.test.sh against tests/runtime/fixtures/arbiter/importance-disagreement.cycle/. The expected.json must reflect consensus: false with exactly one entry in contradictions classified as importance-disagreement. The arbiter rubric in agents/council-arbiter.md must classify importance disagreements (one persona says a concern is critical, another says it is minor) as counting contradictions — not tone-only.",
  "sensor": "tests-sensors",
  "evidence": "Snapshot cycle-1.yaml: no Sprint 02 entries. Disk check: agents/council-arbiter.md ABSENT; tests/sensors/council-arbiter.test.sh ABSENT; tests/runtime/fixtures/arbiter/importance-disagreement.cycle/ ABSENT. AC Scenario 8 / FR-4 ### Validation: 'pass = importance-disagreement.cycle/ produces one entry classified importance-disagreement'. All target files absent = fail (tests-sensors sensor; any-fail-wins). code-review sensor: inferential, lag-by-one absent — skip (reason: inferential — pending Task spawn for cycle 2 lag-by-one)."
}
```

### Criterion: arbiter-ignores-tone-only (Scenario 8 / FR-4)

```json
{
  "criterion": "arbiter-ignores-tone-only",
  "status": "fail",
  "location": "agents/council-arbiter.md, tests/sensors/council-arbiter.test.sh, tests/runtime/fixtures/arbiter/tone-only.cycle/",
  "fix_instruction": "Same target files as arbiter-detects-direct-contradiction. The tone-only branch is exercised by tests/sensors/council-arbiter.test.sh against tests/runtime/fixtures/arbiter/tone-only.cycle/. The expected.json must reflect consensus: true with empty contradictions list and a non-empty tone_only_pairs list. The arbiter rubric in agents/council-arbiter.md must NOT count tone-only differences (stylistic variations, formality differences without semantic disagreement) as contradictions.",
  "sensor": "tests-sensors",
  "evidence": "Snapshot cycle-1.yaml: no Sprint 02 entries. Disk check: agents/council-arbiter.md ABSENT; tests/sensors/council-arbiter.test.sh ABSENT; tests/runtime/fixtures/arbiter/tone-only.cycle/ ABSENT. AC Scenario 8 / FR-4 ### Validation: 'pass = tone-only.cycle/ produces consensus: true with empty contradictions and non-empty tone_only_pairs'. All target files absent = fail (tests-sensors sensor; any-fail-wins). code-review sensor: inferential, lag-by-one absent — skip (reason: inferential — pending Task spawn for cycle 2 lag-by-one)."
}
```

### Criterion: trigger4-escalates-on-cap (Scenario 9 / FR-3)

```json
{
  "criterion": "trigger4-escalates-on-cap",
  "status": "fail",
  "location": "lib/runtime/trigger-4.sh, tests/sensors/trigger4-escalates-on-divergence.test.sh, tests/runtime/fixtures/phase-b-cap-exhausted/",
  "fix_instruction": "Implement Task s02-t04: generalize the Trigger-4 escalation surface. Add lib/runtime/trigger-4.sh::render that takes the merged view + last arbiter verdict and emits the escalation message (markdown render, persona pairs listed, directive line) per the spec's Trigger 4 escalation message contract. Update lib/ralph-loop/escalate.sh callers to wire the new render path. Create tests/runtime/fixtures/phase-b-cap-exhausted/ with two engineered unresolved contradictions across three personas. Add tests/sensors/trigger4-escalates-on-divergence.test.sh that runs /yoke:implement against the fixture and asserts: escalation message is written to the existing surface; each persona pair is listed (e.g. 'sr-eng x sr-qa', 'sr-qa x sr-staff'); arbiter last verdict summary is present; directive line is present. Second test asserts 'ratify sr-qa' and 'rework needed: <text>' replies are parsed and applied as the cycle's resolution.",
  "sensor": "tests-sensors",
  "evidence": "Snapshot cycle-1.yaml: no Sprint 02 entries. Disk check: lib/runtime/trigger-4.sh ABSENT; tests/sensors/trigger4-escalates-on-divergence.test.sh ABSENT; tests/runtime/fixtures/phase-b-cap-exhausted/ ABSENT. AC Scenario 9 / FR-3 ### Validation: 'pass = tests/sensors/trigger4-escalates-on-divergence.test.sh exits 0 AND the rendered escalation message contains every flagged persona pair'. All target files absent = fail (tests-sensors sensor; any-fail-wins). tests-runtime also gates this criterion (council-phase-b.test.sh cap-exhausted branch); absent = fail."
}
```

### Sprint 02 Cycle 1 summary

Verdicts for the eight Sprint 02 active criteria:

| Criterion | Status | Gating sensors | Notes |
|---|---|---|---|
| phase-a-parallel-spawn | fail | tests-runtime, lint | All target files absent — no implementation landed |
| phase-b-runs-on-barrier | fail | tests-runtime, tests-sensors, lint | All target files absent — no implementation landed |
| council-round-cap-configurable | fail | tests-runtime, lint | All target files absent — no implementation landed |
| quiescence-ends-cycle | fail | tests-runtime, lint | All target files absent — no implementation landed |
| arbiter-detects-direct-contradiction | fail | tests-sensors, lint; code-review skip | All target files absent; code-review inferential skip (lag-by-one absent) |
| arbiter-detects-importance-disagreement | fail | tests-sensors, lint; code-review skip | All target files absent; code-review inferential skip (lag-by-one absent) |
| arbiter-ignores-tone-only | fail | tests-sensors, lint; code-review skip | All target files absent; code-review inferential skip (lag-by-one absent) |
| trigger4-escalates-on-cap | fail | tests-runtime, tests-sensors, lint | All target files absent — no implementation landed |

**Summary: 0 pass / 8 fail / 0 skip / 0 divergence — Sprint 02 cycle 1 has no implementation.**

No Sprint 02 Generator work has landed. This is the first cycle of a new sprint; the Generator must implement all four Sprint 02 tasks (s02-t01 through s02-t04) over the next cycles. The three code-review inferential sensors (for Scenario 8 / FR-4 criteria) are skip due to the lag-by-one absence of `.yoke/runtime/.judge-verdicts/cycle-0/`; they will be schedulable in cycle 2 once the arbiter implementation lands and the coordinator spawns inferential judges. No sprint-contract conflicts detected; no Trigger 4 escalation warranted.

**schedule_next for cycle 2:**

```yaml
schedule_next:
  sensors:
    - tests-runtime
    - tests-sensors
    - lint
    - code-review
  tiers:
    - cheap
  reason: >
    Sprint 02 Cycle 1 verdicts: all 8 criteria fail (0 pass / 8 fail). No implementation
    has landed. The Generator must implement Tasks s02-t01 through s02-t04 in the next
    cycle(s). AC FR-2 (Scenario 6) Validation cites tests-runtime + lint; AC FR-3
    (Scenarios 7 and 9) cites tests-runtime + tests-sensors + lint; AC FR-4 (Scenario 8)
    cites tests-sensors + code-review + lint. tests-runtime gates phase-a-parallel-spawn,
    phase-b-runs-on-barrier, council-round-cap-configurable, quiescence-ends-cycle, and
    trigger4-escalates-on-cap (all fail). tests-sensors gates phase-b-runs-on-barrier,
    arbiter-detects-direct-contradiction, arbiter-detects-importance-disagreement,
    arbiter-ignores-tone-only, and trigger4-escalates-on-cap (all fail). code-review is
    inferential and gates the three Scenario 8 / FR-4 criteria; include it to ensure
    arbiter rubric implementation is reviewed in the cycle after the arbiter lands.
    All three computational sensors are cheap-tier (token_cost: 0, time_cost: 30).
```

## Sprint 03 Cycle 1 — Validator Verdicts

> Emitted by the Validator at 2026-05-01 (cycle 1, sprint 03).
> Snapshot: `.yoke/runtime/.snapshots/cycle-1.yaml` — two sensors present (`lint: pass`,
> `tests-runtime: pass`). The `tests-runtime` pass reflects only the pre-existing
> Sprint 01 + 02 tests; the Sprint 03 gating tests do NOT exist on disk and are
> therefore not exercised by this snapshot.
> Inferential sensor lag-by-one: `.yoke/runtime/.judge-verdicts/cycle-1/` contains
> only `Scenario_8-code-review.json` (status: skip) — no Sprint 03 inferential
> verdicts present. Sprint 03 inferential sensors (`code-review`, `llm-as-judge`)
> are recorded as `skip` per the lag-by-one protocol.

---

### Criterion: sr-eng-retooled-prompt-objective (Scenario 10 / FR-5)

AC FR-5 `### Validation` — tests-runtime: **pass = `tests/runtime/sr-eng-prompt-shape.test.sh` exits 0**.
Agent body inspection: `agents/sr-eng.md` carries all four required sections (Objective preamble, Phase A, Phase B, Anti-scope) per Sprint 03 DoD. However, the gating test does not exist on disk; the snapshot's `tests-runtime: pass` does not cover it.

```json
{
  "criterion": "sr-eng-retooled-prompt-objective",
  "status": "fail",
  "location": "tests/runtime/sr-eng-prompt-shape.test.sh",
  "fix_instruction": "Create tests/runtime/sr-eng-prompt-shape.test.sh that parses agents/sr-eng.md and asserts: (1) all four prompt sections present (Functional objective / Phase A / Phase B / Anti-scope), (2) anti-scope clause 'tests/acceptance/' present, (3) objective frontmatter cites 'ship working code'. Also create tests/runtime/fixtures/realistic-task/ fixture directory.",
  "sensor": "tests-runtime",
  "evidence": "AC FR-5 Validation block: pass = sr-eng-prompt-shape.test.sh exits 0. File tests/runtime/sr-eng-prompt-shape.test.sh does not exist on disk (confirmed via ls tests/runtime/). Snapshot cycle-1.yaml tests-runtime: pass only covers pre-existing Sprint 01+02 tests. Agent body agents/sr-eng.md is correctly structured (four sections present) but the gating test is absent."
}
```

Inferential sensor: `code-review` — lag-by-one, no prior cycle verdict for this criterion.

```json
{
  "criterion": "sr-eng-retooled-prompt-objective",
  "status": "skip",
  "location": null,
  "fix_instruction": null,
  "sensor": "code-review",
  "evidence": "Inferential sensor, lag-by-one protocol. .yoke/runtime/.judge-verdicts/cycle-1/ contains no sr-eng-retooled-prompt-objective--code-review.json verdict file. First cycle for Sprint 03; no prior judge verdict exists. Recorded as skip per agents/validator.md §Always."
}
```

---

### Criterion: sr-qa-writes-acceptance-tests (Scenario 11 / FR-5)

AC FR-5 `### Validation` — tests-runtime: **pass = `tests/runtime/sr-qa-prompt-shape.test.sh` exits 0** AND `tests/acceptance/<slug>/` contains test files.

```json
{
  "criterion": "sr-qa-writes-acceptance-tests",
  "status": "fail",
  "location": "tests/runtime/sr-qa-prompt-shape.test.sh",
  "fix_instruction": "Create tests/runtime/sr-qa-prompt-shape.test.sh asserting five prompt sections in agents/sr-qa.md (Functional objective, Phase A test-writing, Phase A judging, Phase B, Anti-scope). Create tests/acceptance/.gitkeep to establish the directory. Create tests/runtime/fixtures/sr-qa-three-criteria/ with a fixture acceptance contract containing three criterion IDs.",
  "sensor": "tests-runtime",
  "evidence": "AC FR-5 Validation block: pass = sr-qa-prompt-shape.test.sh exits 0. File tests/runtime/sr-qa-prompt-shape.test.sh does not exist on disk. Additionally, tests/acceptance/ directory does not exist (confirmed via ls — NOT FOUND). Agent body agents/sr-qa.md is correctly structured (five sections present, anti-scope clauses present) but the gating test and the acceptance directory are both absent."
}
```

---

### Criterion: sr-qa-test-directory-namespace (Scenario 11 / FR-5)

AC FR-5 `### Validation` — tests-runtime: **pass = `tests/runtime/sr-qa-test-directory.test.sh` exits 0**.

```json
{
  "criterion": "sr-qa-test-directory-namespace",
  "status": "fail",
  "location": "tests/runtime/sr-qa-test-directory.test.sh",
  "fix_instruction": "Create tests/runtime/sr-qa-test-directory.test.sh: run Sr QA against tests/runtime/fixtures/sr-qa-three-criteria/ fixture; assert three test files appear under tests/acceptance/<slug>/ each containing '# criterion: <id>' header comment. Fixture directory tests/runtime/fixtures/sr-qa-three-criteria/ must also be created with a fixture acceptance contract and sprint file naming three criterion IDs.",
  "sensor": "tests-runtime",
  "evidence": "AC FR-5 Validation block: pass = sr-qa-test-directory.test.sh exits 0. File tests/runtime/sr-qa-test-directory.test.sh does not exist on disk. Fixture tests/runtime/fixtures/sr-qa-three-criteria/ does not exist. Both gating artefacts absent."
}
```

---

### Criterion: sr-staff-review-invocation (Scenario 12 / FR-5)

AC FR-5 `### Validation` — tests-runtime: **pass = `tests/runtime/sr-staff-review-invocation.test.sh` exits 0** AND slice contains exactly one `### Review output` subsection AND at least one `/yoke:search-canonical-memory` query record AND zero `/ultrareview` tokens.

```json
{
  "criterion": "sr-staff-review-invocation",
  "status": "fail",
  "location": "tests/runtime/sr-staff-review-invocation.test.sh",
  "fix_instruction": "Create tests/runtime/sr-staff-review-invocation.test.sh: run Sr Staff against tests/runtime/fixtures/realistic-task/ fixture; assert slice contains exactly one '### Review output' subsection, at least one '/yoke:search-canonical-memory' query record, and grep -c '/ultrareview' returns 0. Requires tests/runtime/fixtures/realistic-task/ fixture to exist.",
  "sensor": "tests-runtime",
  "evidence": "AC FR-5 Validation block: pass = sr-staff-review-invocation.test.sh exits 0. File tests/runtime/sr-staff-review-invocation.test.sh does not exist on disk. Fixture tests/runtime/fixtures/realistic-task/ does not exist. Both gating artefacts absent. agents/sr-staff.md body correctly specifies the review-skill invocation contract (review-skill: /review in frontmatter; Phase A step 2 instructs exactly-one invocation; Phase A step 3 instructs canonical-memory queries; anti-scope prohibits /ultrareview) but no test validates it."
}
```

Inferential sensor: `code-review` — lag-by-one, no prior cycle verdict for this criterion.

```json
{
  "criterion": "sr-staff-review-invocation",
  "status": "skip",
  "location": null,
  "fix_instruction": null,
  "sensor": "code-review",
  "evidence": "Inferential sensor, lag-by-one protocol. .yoke/runtime/.judge-verdicts/cycle-1/ contains no sr-staff-review-invocation--code-review.json verdict file. Recorded as skip."
}
```

---

### Criterion: sr-staff-architectural-canonical-memory-lens (Scenario 12 / FR-5)

AC FR-5 `### Validation` — tests-runtime gates this criterion (same test as `sr-staff-review-invocation`): **`tests/runtime/sr-staff-prompt-shape.test.sh` exits 0**. Also gated by `llm-as-judge` (inferential, lag-by-one).

```json
{
  "criterion": "sr-staff-architectural-canonical-memory-lens",
  "status": "fail",
  "location": "tests/runtime/sr-staff-prompt-shape.test.sh",
  "fix_instruction": "Create tests/runtime/sr-staff-prompt-shape.test.sh: parse agents/sr-staff.md and assert five sections present (Functional objective, Phase A own progress, Phase A canonical memory, Phase A architectural lens, Phase B) plus anti-scope clause naming '/ultrareview'. The 'canonical memory consultation' step in Phase A must be present (step 3: '/yoke:search-canonical-memory' invocation instructions).",
  "sensor": "tests-runtime",
  "evidence": "AC FR-5 Validation block: pass requires sr-staff-prompt-shape.test.sh to exit 0. File does not exist on disk. agents/sr-staff.md body contains the required sections (Phase A step 3 instructs /yoke:search-canonical-memory queries; anti-scope prohibits /ultrareview) but the gating test is absent."
}
```

Inferential sensor: `llm-as-judge` — lag-by-one, no prior cycle verdict.

```json
{
  "criterion": "sr-staff-architectural-canonical-memory-lens",
  "status": "skip",
  "location": null,
  "fix_instruction": null,
  "sensor": "llm-as-judge",
  "evidence": "Inferential sensor, lag-by-one protocol. .yoke/runtime/.judge-verdicts/cycle-1/ contains no sr-staff-architectural-canonical-memory-lens--llm-as-judge.json verdict file. Recorded as skip."
}
```

---

### Criterion: personas-irreducible-on-fixture-cycle (Scenario 12 / FR-5)

AC FR-5 `### Validation` — tests-runtime: **pass = `tests/sensors/personas-irreducible-on-fixture-cycle.test.sh` exits 0** (Sprint 03 DoD explicitly names this file). Also gated by `llm-as-judge` (inferential, lag-by-one).

```json
{
  "criterion": "personas-irreducible-on-fixture-cycle",
  "status": "fail",
  "location": "tests/sensors/personas-irreducible-on-fixture-cycle.test.sh",
  "fix_instruction": "Create tests/sensors/personas-irreducible-on-fixture-cycle.test.sh: run the council on tests/runtime/fixtures/realistic-task/; assert each of the three persona slices carries at least one finding tagged with its distinct concern category (Sr Eng: unit-test gap, Sr QA: acceptance-test gap, Sr Staff: pattern-alignment finding). Requires the realistic-task fixture to exist.",
  "sensor": "tests-runtime",
  "evidence": "Sprint 03 DoD: 'tests/sensors/personas-irreducible-on-fixture-cycle.test.sh exits 0'. AC FR-5 Validation block: tests-runtime gates this criterion. File tests/sensors/personas-irreducible-on-fixture-cycle.test.sh does not exist on disk. Fixture tests/runtime/fixtures/realistic-task/ does not exist. Both absent."
}
```

Inferential sensor: `llm-as-judge` — lag-by-one, no prior cycle verdict.

```json
{
  "criterion": "personas-irreducible-on-fixture-cycle",
  "status": "skip",
  "location": null,
  "fix_instruction": null,
  "sensor": "llm-as-judge",
  "evidence": "Inferential sensor, lag-by-one protocol. .yoke/runtime/.judge-verdicts/cycle-1/ contains no personas-irreducible-on-fixture-cycle--llm-as-judge.json verdict file. Recorded as skip."
}
```

---

### Sprint 03 Cycle 1 summary

```yaml
sprint: "03"
cycle: 1
verdict_counts:
  pass: 0
  fail: 5
  skip: 4    # 4 inferential skip verdicts (code-review x2, llm-as-judge x2)
  divergence: 0
failing_criteria:
  - sr-eng-retooled-prompt-objective       # missing: sr-eng-prompt-shape.test.sh
  - sr-qa-writes-acceptance-tests          # missing: sr-qa-prompt-shape.test.sh + tests/acceptance/
  - sr-qa-test-directory-namespace         # missing: sr-qa-test-directory.test.sh + fixtures/sr-qa-three-criteria/
  - sr-staff-review-invocation             # missing: sr-staff-review-invocation.test.sh + fixtures/realistic-task/
  - sr-staff-architectural-canonical-memory-lens  # missing: sr-staff-prompt-shape.test.sh
skip_criteria:
  - sr-eng-retooled-prompt-objective (code-review)
  - sr-staff-review-invocation (code-review)
  - sr-staff-architectural-canonical-memory-lens (llm-as-judge)
  - personas-irreducible-on-fixture-cycle (llm-as-judge)
convergence_achieved: false
advance_recommendation: >
  Do NOT advance to Sprint 04. Sprint 03 Cycle 1 yields 0 pass / 5 fail / 4 skip.
  All five failing criteria share a common root cause: the Sprint 03 test harness
  (five test scripts) and two fixture directories are absent. The agent bodies
  (agents/sr-eng.md, sr-qa.md, sr-staff.md) are correctly structured and would
  satisfy the shape-parser tests once those tests exist. Generator must create in
  Cycle 2: (1) tests/runtime/sr-eng-prompt-shape.test.sh, (2) tests/runtime/sr-qa-prompt-shape.test.sh,
  (3) tests/runtime/sr-qa-test-directory.test.sh, (4) tests/runtime/sr-staff-prompt-shape.test.sh,
  (5) tests/runtime/sr-staff-review-invocation.test.sh, (6) tests/sensors/personas-irreducible-on-fixture-cycle.test.sh,
  (7) tests/acceptance/.gitkeep, (8) tests/runtime/fixtures/realistic-task/,
  (9) tests/runtime/fixtures/sr-qa-three-criteria/. After those land, all five
  computational criteria are expected to flip to pass in Cycle 2.

---

## Sprint 04 Cycle 1 — Validator Verdicts

> Emitted by the Validator at 2026-05-01T00:00:00Z (cycle 1, sprint 04).
> No Sprint 04 snapshot exists: `.yoke/runtime/progress.md` shows `current_sprint: "04"` and
> `cycle_count: 0` — no Sprint 04 cycle has run yet, so no `.yoke/runtime/.snapshots/cycle-N.yaml`
> exists scoped to Sprint 04. The eight cycle snapshots present (cycle-1 through cycle-8) belong to
> sprints 01-03 (progress.md confirms completed_sprints: ["01","02","03"]).
> No inferential verdicts exist for Sprint 04 (lag-by-one, no prior Sprint 04 cycle).
> All Sprint 04 sensor results: absent. Per the Validator protocol, absent computational sensor
> verdicts for criteria whose gating tests do not exist on disk are recorded as `fail`.

---

### Criterion: legacy-runtime-removed (Scenario 13 / FR-6)

AC FR-6 `### Validation` — tests-runtime: pass = `tests/runtime/legacy-removal.test.sh` exits 0
(`agents/generator.md` and `agents/validator.md` do NOT exist; `agents/orchestrator.md` body has
no `monitor` or `consult` mode subsection; grep of `lib/runtime/ skills/implement/` for legacy
agent names returns 0; `jq -r .version .claude-plugin/plugin.json` returns `3.0.0`).
tests-sensors: pass = `tests/sensors/orchestrator-canonize-survives.test.sh` exits 0.

```json
{
  "criterion": "legacy-runtime-removed (Scenario 13 / FR-6)",
  "status": "fail",
  "location": "agents/generator.md, agents/validator.md, .claude-plugin/plugin.json",
  "fix_instruction": "Delete agents/generator.md and agents/validator.md. Edit agents/orchestrator.md: remove the 'monitor' and 'consult' mode descriptions from the description frontmatter field and from the body (13 grep hits on 'monitor|consult' currently). Audit lib/runtime/ and skills/implement/ to remove every code path referencing generator, validator, orchestrator-monitor, or orchestrator-consult (3 files currently match: lib/runtime/persona-loader.sh, lib/runtime/agent-config.sh, skills/implement/SKILL.md). Bump .claude-plugin/plugin.json version from '2.0.0' to '3.0.0' and update the description string to mention 'agent council'. Create tests/runtime/legacy-removal.test.sh and tests/sensors/legacy-agents-removed.test.sh.",
  "sensor": "tests-runtime",
  "evidence": "Disk state at cycle 1: agents/generator.md EXISTS (must be deleted). agents/validator.md EXISTS (must be deleted). agents/orchestrator.md body contains 13 lines matching 'monitor|consult' — the 'consult' and 'monitor' mode descriptions are still present. lib/runtime/ + skills/implement/ grep returns 3 matching files (not 0). plugin.json version is '2.0.0' (not '3.0.0'). plugin.json description mentions 'Generator, Validator, Orchestrator' (no 'agent council'). Test file tests/runtime/legacy-removal.test.sh does not exist. Test file tests/sensors/legacy-agents-removed.test.sh does not exist. AC FR-6 Validation block interpretation: fail = any residual. Multiple residuals found."
}
```

---

### Criterion: orchestrator-canonize-intact (Scenario 13 / FR-6)

AC FR-6 `### Validation` — tests-sensors: pass = `tests/sensors/orchestrator-canonize-survives.test.sh`
exits 0 (orchestrator file frontmatter mentions `canonize` AND `/yoke:canonize` is callable
end-to-end on a fixture run). build: pass = directory layout matches
`concepts/yoke-pattern-plugin-structure` (no leftover legacy agent files or mode subsections).

```json
{
  "criterion": "orchestrator-canonize-intact (Scenario 13 / FR-6)",
  "status": "fail",
  "location": "tests/sensors/orchestrator-canonize-survives.test.sh",
  "fix_instruction": "Create tests/sensors/orchestrator-canonize-survives.test.sh: assert agents/orchestrator.md frontmatter description contains 'canonize' AND invoke /yoke:canonize via a fixture run to confirm end-to-end callability. The orchestrator's canonize mode text itself is present in the current file and must be preserved during the monitor/consult removal edit.",
  "sensor": "tests-sensors",
  "evidence": "Test file tests/sensors/orchestrator-canonize-survives.test.sh does not exist on disk. AC FR-6 Validation block: tests-sensors gates this criterion; pass requires the test file to exit 0. Absent test file = fail. Note: agents/orchestrator.md frontmatter does currently contain 'canonize' (the canonical mode description is intact) — the underlying artifact is correct but the sensor test that verifies it is absent. build sensor is also unverifiable while legacy agent files remain on disk."
}
```

---

### Criterion: docs-reflect-council (Scenario 14 / FR-7)

AC FR-7 `### Validation` — tests-sensors: pass = `tests/sensors/claude-md-mentions-council.test.sh`
exits 0 (greps CLAUDE.md for 'agent council', 'Sr Eng', 'Sr QA', 'Sr Staff', 'Phase A') AND
`tests/sensors/migration-note-present.test.sh` exits 0 AND `grep -c "Council protocol"
docs/architecture.md` >= 1 AND existing v1->v2 migration docs untouched.
tests-runtime: pass = `tests/runtime/docs-shape.test.sh` exits 0.

```json
{
  "criterion": "docs-reflect-council (Scenario 14 / FR-7)",
  "status": "fail",
  "location": "CLAUDE.md, docs/architecture.md",
  "fix_instruction": "Rewrite CLAUDE.md '## What Yoke is' and '## Architecture' sections to describe the council runtime (three personas Sr Eng/Sr QA/Sr Staff, Phase A/B/C, sync barrier, contradiction-detection arbiter, Trigger 4 generalization, Orchestrator-canonize survives). Update the Migration history section with a v3.0.0 council cutover entry. Extend docs/architecture.md with a new '## Council protocol' section containing a text-based or mermaid diagram of the cycle phases and persona/arbiter dispatch path. Create tests/sensors/claude-md-mentions-council.test.sh and tests/runtime/docs-shape.test.sh.",
  "sensor": "tests-sensors",
  "evidence": "Disk state at cycle 1: CLAUDE.md grep for 'agent council' returns 0. grep for 'Sr Eng' returns 0. grep for 'Sr QA' returns 0. grep for 'Sr Staff' returns 0. grep for 'Phase A' returns 0. docs/architecture.md grep for 'Council protocol' returns 0. Test file tests/sensors/claude-md-mentions-council.test.sh does not exist. Test file tests/runtime/docs-shape.test.sh does not exist. AC FR-7 Validation block interpretation: fail = any token missing. All five CLAUDE.md tokens are missing and the council-protocol section is absent from architecture.md."
}
```

---

### Criterion: migration-note-shipped (Scenario 14 / FR-7)

AC FR-7 `### Validation` — tests-sensors: pass = `tests/sensors/migration-note-present.test.sh`
exits 0 (`docs/migration-v2-to-v3.md` exists with the literal one-line migration note
"drain in-flight v2.x cycles before upgrading").

```json
{
  "criterion": "migration-note-shipped (Scenario 14 / FR-7)",
  "status": "fail",
  "location": "docs/migration-v2-to-v3.md",
  "fix_instruction": "Create docs/migration-v2-to-v3.md with: (1) the literal one-line migration note 'drain in-flight v2.x cycles before upgrading', (2) a short context paragraph explaining why no formal runbook is required (PRD Resolved 10), and (3) a pointer to the council architecture docs. Verify existing docs/migration-v1-to-v2.md is untouched. Create tests/sensors/migration-note-present.test.sh: assert the file exists and contains the literal one-line note.",
  "sensor": "tests-sensors",
  "evidence": "docs/migration-v2-to-v3.md does not exist on disk (ls returns 'No such file or directory'). Test file tests/sensors/migration-note-present.test.sh does not exist. AC FR-7 Validation block: pass requires migration-note-present.test.sh exits 0, which requires the doc to exist with the literal note. Absent doc = fail. Note: existing docs/migration-v1-to-v2.md exists and is untouched — the preservation invariant for v1->v2 docs is currently satisfied."
}
```

---

### Criterion: dogfood-entry-committed (Scenario 15 / FR-7)

AC Scenario 15 `### Validation` — tests-runtime: pass = `tests/runtime/dogfood-entry-shape.test.sh`
exits 0 AND `grep -c '^## Dogfood entry point$' .yoke/specs/2026-05-01-agent-council.md` returns
exactly 1 AND the section contains a slug-shaped value, a rationale paragraph, and a handoff line.

```json
{
  "criterion": "dogfood-entry-committed (Scenario 15 / FR-7)",
  "status": "fail",
  "location": ".yoke/specs/2026-05-01-agent-council.md",
  "fix_instruction": "Append a '## Dogfood entry point' section to .yoke/specs/2026-05-01-agent-council.md naming: (1) a concrete Yoke task slug for the first v3.0 dogfood task (e.g., a small low-risk improvement like agents-have-current-sprint sensor extension or wm_* helper polish), (2) a rationale paragraph (low blast radius, clear acceptance criterion, exercises all three personas), (3) a date-target ordering signal, and (4) an explicit handoff line to the v3.0-dogfood follow-up PRD. Create tests/runtime/dogfood-entry-shape.test.sh: parse the spec for the '## Dogfood entry point' heading and assert presence of a slug-shaped value, a rationale paragraph, and a handoff line.",
  "sensor": "tests-runtime",
  "evidence": "grep -c '^## Dogfood entry point$' .yoke/specs/2026-05-01-agent-council.md returns 0 (section absent). Test file tests/runtime/dogfood-entry-shape.test.sh does not exist. AC Scenario 15 Validation block: pass requires the test exits 0 AND the grep returns exactly 1. Both conditions are unmet."
}
```

---

### Sprint 04 Cycle 1 summary

```yaml
sprint: "04"
cycle: 1
verdict_counts:
  pass: 0
  fail: 5
  skip: 0
  divergence: 0
failing_criteria:
  - legacy-runtime-removed          # agents/generator.md and agents/validator.md still exist; orchestrator has monitor/consult; plugin.json == 2.0.0; 3 lib/runtime+skills/implement legacy ref files; test files absent
  - orchestrator-canonize-intact    # tests/sensors/orchestrator-canonize-survives.test.sh absent
  - docs-reflect-council            # CLAUDE.md missing all 5 council tokens; docs/architecture.md missing Council protocol; test files absent
  - migration-note-shipped          # docs/migration-v2-to-v3.md absent; test file absent
  - dogfood-entry-committed         # spec missing '## Dogfood entry point'; test file absent
convergence_achieved: false
advance_recommendation: >
  Do NOT advance to MERGE-READY. Sprint 04 Cycle 1 yields 0 pass / 5 fail / 0 skip.
  All five failing criteria share a common root cause: no Sprint 04 implementation has
  landed yet. The Generator must deliver in Cycle 2:
  (1) Delete agents/generator.md and agents/validator.md.
  (2) Edit agents/orchestrator.md: remove monitor and consult mode subsections from both
      frontmatter description and body; preserve canonize mode intact.
  (3) Audit and patch lib/runtime/persona-loader.sh, lib/runtime/agent-config.sh, and
      skills/implement/SKILL.md to remove the legacy generator/validator/orchestrator-monitor/
      orchestrator-consult name references.
  (4) Bump .claude-plugin/plugin.json version to '3.0.0'; update description to mention
      'agent council'.
  (5) Rewrite CLAUDE.md architecture sections to describe the council runtime with tokens
      'agent council', 'Sr Eng', 'Sr QA', 'Sr Staff', 'Phase A'.
  (6) Add '## Council protocol' section to docs/architecture.md.
  (7) Create docs/migration-v2-to-v3.md with the literal one-line migration note.
  (8) Append '## Dogfood entry point' section to .yoke/specs/2026-05-01-agent-council.md.
  (9) Create all five test files:
      tests/sensors/legacy-agents-removed.test.sh,
      tests/sensors/orchestrator-canonize-survives.test.sh,
      tests/sensors/claude-md-mentions-council.test.sh,
      tests/sensors/migration-note-present.test.sh,
      tests/runtime/dogfood-entry-shape.test.sh.
  After those land and all tests exit 0, all five criteria are expected to flip to pass
  in Cycle 2, enabling MERGE-READY canonize handoff.
```
```
