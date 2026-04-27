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

## Contract c1 — Cycle 2 Validator verdicts
- id: "c1"
- topic: "Cycle 2 per-criterion verdicts from the Validator against the cycle-1 computational sensor snapshot"
- decision: "FR-1 / FR-10 / Scenario 1 are confirmed PASS (cascade-occurrences-test green in cycle 1). FR-2 / FR-8 / Scenario 2 are FAIL (semantic-overlap-rewrite-test exit 127 — test file absent). FR-3 / FR-5 are FAIL (promoted-concept-frontmatter-test exit 127). FR-4 is FAIL (promoted-concept-backlink-test, contract-promotion-bidirectional-self-test, contract-promotion-bidirectional-integration all exit 127). FR-6 is FAIL (promoted-concept-slug-collision-test exit 127). FR-7 is FAIL (promoted-concept-actor-create-test exit 127). FR-9 is FAIL with an actionable gap: ack-sensors.sh rejects --sensor <id> argument (exit 2); fix is Generator-owned — extend ack-sensors.sh to accept --sensor <id> filtering, not a contract relaxation. shellcheck-new-scripts is SKIP (binary absent, environmental). Consensus on s01-t01 group is reached (PASS confirmed); remaining criteria remain open."
- rationale: "cascade-occurrences-test passed all 5 subtests in cycle 1 (cycle-1.yaml sensor row: status=pass, exit_code=0); all three criteria it covers (FR-1, FR-10, Scenario 1) share the same sensor and the same passing evidence. All other sensor rows show exit_code=127 (file not found) — test files have not yet been created. FR-9 additionally shows a tool-contract gap in ack-sensors.sh itself, which is actionable and does not require Acceptance Contract modification."
- timestamp: "2026-04-27T22:45:00Z"
- agents_involved: [validation]
- references:
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-1"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-2"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-3"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-4"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-5"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-6"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-7"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-8"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-9"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-10"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#Scenario-1"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#Scenario-2"
- cycle: 2
- schedule_next:
    sensors:
      - cascade-occurrences-test
      - semantic-overlap-rewrite-test
    tiers: [cheap]
    reason: "cascade-occurrences-test cycle-1 run status=pass (sensor file .yoke/sensors/cascade-occurrences-test.md, runs[0].status=pass) — cheap tier continues to guard the already-green s01-t01 group. semantic-overlap-rewrite-test cycle-1 run status=fail with exit_code=127 (sensor file .yoke/sensors/semantic-overlap-rewrite-test.md, runs[0].status=fail); Generator targets s01-t02 in cycle 2 which is the applies_to surface for this sensor — it must run in cycle 3 to verify the new implementation. No expensive-tier sensors declared in this AC; all sensors are computational cheap-tier. Tier-expensive is not authorized — cheap was not green for all targeted criteria in cycle 1 and no diff surface maps to any expensive sensor."

### Verdicts

```json
[
  {
    "criterion": "FR-1",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "exit_code=0. ✓ (1) legacy single-file path emits additive occurrences: 1 only | ✓ (2) single per-task archive emits occurrences: 1 with per-archive traceability | ✓ (3) cross-archive recurrence emits occurrences: 2 with cross-archive traceability (FR-1) | ✓ (3*) cross-archive fixture stdout contains 'occurrences: 2' (binding criterion) | ✓ (4) distinct topics differing by one char remain occurrences: 1 (no coalescing)"
  },
  {
    "criterion": "FR-10",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "exit_code=0. Subtest (1) confirms legacy single-file path emits additive occurrences: 1 only — golden output preserved except additive field. Full output matches FR-10 binding subcase."
  },
  {
    "criterion": "Scenario 1",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "exit_code=0. All 5 Scenario 1 subcases confirmed: occurrences: 2 cross-archive, occurrences: 1 distinct-topic isolation, legacy golden path, single-archive traceability, and performance <5s (reported 120ms)."
  },
  {
    "criterion": "FR-2",
    "status": "fail",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": "Create tests/canonical-memory/semantic-overlap-rewrite.test.sh implementing the cohesive-case, split-case, and contradiction-case fixtures declared in Scenario 2 with a canned LLM-judge stub; create tests/canonical-memory/fixtures/semantic-overlap-rewrite/ with the three fixture directories.",
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "exit_code=127. bash: tests/canonical-memory/semantic-overlap-rewrite.test.sh: No such file or directory"
  },
  {
    "criterion": "FR-8",
    "status": "fail",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": "FR-8 is a subcase of the same semantic-overlap-rewrite-test sensor. The contradiction-case fixture must assert that impact class is escalated to require synchronous human ratification (Trigger 5) and the YAML emits a top-level notes: entry. Implement as part of the same test file creation covering FR-2.",
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "exit_code=127. bash: tests/canonical-memory/semantic-overlap-rewrite.test.sh: No such file or directory — contradiction-subcase never reached."
  },
  {
    "criterion": "Scenario 2",
    "status": "fail",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": "Implement the semantic-overlap layer in lib/canonical-memory/canonization-criteria.sh (or a new lib/canonical-memory/semantic-overlap.sh) plus the test harness at tests/canonical-memory/semantic-overlap-rewrite.test.sh with all three fixture subcases (cohesive, split, contradiction). The cohesive case must emit occurrences: 2 with reason: referencing both originating contracts; the split case must produce two occurrences: 1 entries; the contradiction case must emit notes: with escalation signal.",
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "exit_code=127. bash: tests/canonical-memory/semantic-overlap-rewrite.test.sh: No such file or directory"
  },
  {
    "criterion": "FR-3",
    "status": "fail",
    "location": "tests/canonical-memory/promoted-concept-frontmatter.test.sh",
    "fix_instruction": "Create lib/canonical-memory/write-promoted-concept.sh producing a concept entity with the mandatory rippability frontmatter fields (ratified, model_calibrated_against, last_validated, traceability, impact_level, type, name, aliases, description, status, applies_to, depends_on, supersedes, contradicts_with, tags containing both kind/contract and yoke-framework, project). Create tests/canonical-memory/promoted-concept-frontmatter.test.sh asserting every mandatory field is non-empty and tags contains both required values.",
    "sensor": "promoted-concept-frontmatter-test",
    "evidence": "exit_code=127. bash: tests/canonical-memory/promoted-concept-frontmatter.test.sh: No such file or directory"
  },
  {
    "criterion": "FR-5",
    "status": "fail",
    "location": "tests/canonical-memory/promoted-concept-frontmatter.test.sh",
    "fix_instruction": "FR-5 is a subcase of promoted-concept-frontmatter-test: tags: list must contain both 'kind/contract' and 'yoke-framework'. Verified within the same test file as FR-3.",
    "sensor": "promoted-concept-frontmatter-test",
    "evidence": "exit_code=127. bash: tests/canonical-memory/promoted-concept-frontmatter.test.sh: No such file or directory"
  },
  {
    "criterion": "FR-4",
    "status": "fail",
    "location": null,
    "fix_instruction": "Three sensors all missing (all exit 127): (1) promoted-concept-backlink-test — create tests/canonical-memory/promoted-concept-backlink.test.sh verifying the actor's ## Recent Activity section contains [[<concept-slug>]] wikilink; (2) contract-promotion-bidirectional-self-test — create tests/sensors/contract-promotion-bidirectional.test.sh covering positive/negative/reverse-fixture cases per Scenario 4; (3) contract-promotion-bidirectional-integration — create tests/canonical-memory/contract-promotion-bidirectional-integration.test.sh running the sensor against the Scenario 3 positive fixture. All three tests depend on lib/canonical-memory/write-promoted-concept.sh and lib/sensors/contract-promotion-bidirectional.sh existing first.",
    "sensor": "promoted-concept-backlink-test",
    "evidence": "promoted-concept-backlink-test exit_code=127 (No such file or directory); contract-promotion-bidirectional-self-test exit_code=127 (No such file or directory); contract-promotion-bidirectional-integration exit_code=127 (No such file or directory). All three sensors covering FR-4 fail."
  },
  {
    "criterion": "FR-6",
    "status": "fail",
    "location": "tests/canonical-memory/promoted-concept-slug-collision.test.sh",
    "fix_instruction": "Add slug-collision retry logic (up to 5 attempts) to lib/canonical-memory/write-promoted-concept.sh and create tests/canonical-memory/promoted-concept-slug-collision.test.sh with a fixture pre-seeding concepts/<topic-slug>.md; assert the helper retries and eventually exits non-zero on exhaustion when every retry produces the same colliding slug.",
    "sensor": "promoted-concept-slug-collision-test",
    "evidence": "exit_code=127. bash: tests/canonical-memory/promoted-concept-slug-collision.test.sh: No such file or directory"
  },
  {
    "criterion": "FR-7",
    "status": "fail",
    "location": "tests/canonical-memory/promoted-concept-actor-create.test.sh",
    "fix_instruction": "Add actor-creation logic to lib/canonical-memory/write-promoted-concept.sh (or a new lib/working-memory/host-actor.sh): when the actor entity is absent, create it from the canonical actor template with well-formed frontmatter per entities/actor.md shape and seed the body with the backlink. Create tests/canonical-memory/promoted-concept-actor-create.test.sh verifying the actor file is created and the backlink is present.",
    "sensor": "promoted-concept-actor-create-test",
    "evidence": "exit_code=127. bash: tests/canonical-memory/promoted-concept-actor-create.test.sh: No such file or directory"
  },
  {
    "criterion": "FR-9",
    "status": "fail",
    "location": "lib/sensors/ack-sensors.sh",
    "fix_instruction": "ACTIONABLE TOOL-CONTRACT GAP. The AC's sensor command for contract-promotion-bidirectional-readiness is 'bash lib/sensors/ack-sensors.sh --mode readiness --sensor contract-promotion-bidirectional', but ack-sensors.sh does not accept --sensor <id> and exits 2 with 'Error: unexpected argument: contract-promotion-bidirectional'. Recommended fix (option a, preferred): extend lib/sensors/ack-sensors.sh to accept an optional '--sensor <id>' argument that filters readiness output to a single sensor id by substring match against the sensor's command path. This adds a genuinely useful scoped-readiness capability without modifying the binding Acceptance Contract. Option (b) — revising the AC command shape — requires a sprint contract refinement and explicit Orchestrator sign-off; use only if option (a) is infeasible. The Generator must pick up option (a) in the current or next cycle.",
    "sensor": "contract-promotion-bidirectional-readiness",
    "evidence": "exit_code=2. Error: unexpected argument: contract-promotion-bidirectional. Source: cycle-1.yaml sensor row contract-promotion-bidirectional-readiness, and .yoke/sensors/contract-promotion-bidirectional-readiness.md runs[0].evidence_snippet."
  },
  {
    "criterion": "shellcheck-new-scripts",
    "status": "skip",
    "location": null,
    "fix_instruction": "Environmental skip — shellcheck binary not found. Install shellcheck in CI or developer environment. Not a code gap; no Generator action required.",
    "sensor": "shellcheck-new-scripts",
    "evidence": "exit_code=-1. reason: binary not found: shellcheck. Environmental constraint, not a test-file-missing case."
  }
]
```

> Schema notes:
>
> - `schedule_next` mirrors the Validator's per-cycle decision verbatim
>   (added in v0.8.0 by sensor-cost-tiering Part 4). When consensus is
>   reached on a sub-objective, the scheduling decision active at that
>   cycle is captured here for audit. At least one of `sensors:` or
>   `tiers:` MUST be non-empty; `reason:` MUST cite at least one signal
>   source. Source PRD: `.yoke/prds/2026-04-27-sensor-cost-tiering.md`.

## Contract c2 — Cycle 3 Validator verdicts
- id: "c2"
- topic: "Cycle 3 per-criterion verdicts: semantic-overlap rewriter PASS confirmed; s01-t03 sensors remain open; mechanical interpretation of verdicts-file decoupling pinned"
- decision: "FR-2 / FR-8 / Scenario 2 are confirmed PASS (semantic-overlap-rewrite-test green in cycle 2, all 9 assertions confirmed including the FR-8 contradiction-subcase surface to Trigger 5). The mechanical interpretation is pinned: the verdicts-file decoupling (canned TSV stub injected into the rewriter) lets the test prove correctness of the orchestration logic independent of live LLM behaviour — this refines the AC's Scenario 2 fixture description ('a stubbed cascade-scoring LLM judge that returns the canned cohesive verdict') without relaxing it; the live LLM smoke remains informational behind YOKE_RUN_LIVE_LLM_SMOKE=1 as declared in the AC. FR-3 / FR-5 FAIL (promoted-concept-frontmatter-test exit 127 — cycle-3 Generator target). FR-4 FAIL (all three sensors: promoted-concept-backlink-test, contract-promotion-bidirectional-self-test, contract-promotion-bidirectional-integration all exit 127). FR-6 FAIL (promoted-concept-slug-collision-test exit 127). FR-7 FAIL (promoted-concept-actor-create-test exit 127). FR-9 FAIL (contract-promotion-bidirectional-readiness exit 2 — ack-sensors.sh still rejects --sensor argument; actionable fix from cycle-2 pending in Generator). shellcheck skip (binary absent, environmental). Consensus on s01-t02 group reached (PASS confirmed); s01-t03 sensors remain the Generator's cycle-3 target."
- rationale: "semantic-overlap-rewrite-test cycle-2 run status=pass, exit_code=0 (cycle-2.yaml sensor row; sensor file .yoke/sensors/semantic-overlap-rewrite-test.md runs[1].status=pass). All FR-2 / FR-8 / Scenario 2 binding subcases confirmed including the no-invent invariant and contradiction escalation. Verdicts-file decoupling is a refinement within the AC envelope: Scenario 2 explicitly names a stubbed judge and a fixture directory; the TSV stub is the mechanical realisation of that stub — no relaxation of any criterion. All s01-t03 sensors continue to show exit_code=127 (file not found); no file exists yet at cycle-3 start (per cycle-2.yaml rows). FR-9 gap: contract-promotion-bidirectional-readiness.md runs[0..1] both show 'Error: unexpected argument: contract-promotion-bidirectional' — two consecutive fails confirm the ack-sensors.sh tool-contract gap is not a flake and is actionable."
- timestamp: "2026-04-27T23:08:00Z"
- agents_involved: [validation]
- references:
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-2"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-3"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-4"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-5"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-6"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-7"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-8"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-9"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#Scenario-2"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#Scenario-3"
- cycle: 3
- schedule_next:
    sensors:
      - promoted-concept-frontmatter-test
      - promoted-concept-backlink-test
      - promoted-concept-actor-create-test
      - promoted-concept-slug-collision-test
      - cascade-occurrences-test
      - semantic-overlap-rewrite-test
    tiers: [cheap]
    reason: "Generator targets s01-t03 in cycle 3 (FR-3 / FR-5 / FR-4 / FR-6 / FR-7 — Scenario 3): the four s01-t03 sensors (promoted-concept-frontmatter-test, promoted-concept-backlink-test, promoted-concept-actor-create-test, promoted-concept-slug-collision-test) all showed exit_code=127 in cycle-2.yaml (files not found) and are the primary verification signal for the Generator's intended cycle-3 changes. cascade-occurrences-test and semantic-overlap-rewrite-test are included as regression guards: semantic-overlap-rewrite.sh consumes canonization-criteria.sh stdout (any structural cascade YAML change would silently break the rewrite path — FR-10 / FR-2 envelope); both sensors were green in cycle-2.yaml (runs[1].status=pass in their respective sensor files). No expensive-tier sensors declared in this AC; all sensors are computational cheap-tier. contract-promotion-bidirectional-readiness deferred to cycle 4 because it maps to s01-t04 and the fix prerequisite (lib/sensors/ack-sensors.sh --sensor argument extension) is a Generator-owned change not yet present in the cycle-3 target scope."

### Verdicts

```json
[
  {
    "criterion": "FR-1",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "cycle-2.yaml exit_code=0. ✓ (1) legacy single-file path emits additive occurrences: 1 only | ✓ (2) single per-task archive emits occurrences: 1 with per-archive traceability | ✓ (3) cross-archive recurrence emits occurrences: 2 with cross-archive traceability (FR-1) | ✓ (3*) cross-archive fixture stdout contains 'occurrences: 2' (binding criterion) | ✓ (4) distinct topics differing by one char remain occurrences: 1 (no coalescing)"
  },

  {
    "criterion": "FR-10",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "cycle-2.yaml exit_code=0. Subtest (1) confirms legacy single-file path emits additive occurrences: 1 only — golden output preserved except additive field. FR-10 binding subcase confirmed."
  },
  {
    "criterion": "Scenario 1",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "cycle-2.yaml exit_code=0. All 5 Scenario 1 subcases confirmed: occurrences: 2 cross-archive, occurrences: 1 distinct-topic isolation, legacy golden path, single-archive traceability, and performance <5s."
  },
  {
    "criterion": "FR-2",
    "status": "pass",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": null,
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "cycle-2.yaml exit_code=0. ✓ (1) cohesive case emits exactly one merged candidate with occurrences: 2 | ✓ (1*) cohesive merged candidate's reason references both originating contracts (Scenario 2 binding) | ✓ (1**) cohesive case emits no contradiction notes | ✓ (2) split case emits two candidates each with occurrences: 1 and no cohesive group | ✓ (2*) split case emits no contradiction notes"
  },
  {
    "criterion": "FR-8",
    "status": "pass",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": null,
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "cycle-2.yaml exit_code=0. FR-8 contradiction-subcase covered by the semantic-overlap-rewrite-test suite. sensor file .yoke/sensors/semantic-overlap-rewrite-test.md runs[1].status=pass confirms full test suite green including contradiction escalation routing to synchronous human ratification (Trigger 5 surface via top-level notes: block)."
  },
  {
    "criterion": "Scenario 2",
    "status": "pass",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": null,
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "cycle-2.yaml exit_code=0. All Scenario 2 binding subcases confirmed: cohesive emits occurrences: 2 with reason referencing both originating contracts; split emits two occurrences: 1 candidates; contradiction emits notes: block with escalation signal; no-invent invariant upheld (deterministic-floor occurrences: 1 candidate not promoted regardless of verdict)."
  },
  {
    "criterion": "FR-3",
    "status": "fail",
    "location": "tests/canonical-memory/promoted-concept-frontmatter.test.sh",
    "fix_instruction": "Create lib/canonical-memory/write-promoted-concept.sh producing a concept entity with mandatory rippability frontmatter (ratified, model_calibrated_against, last_validated, traceability, impact_level, type, name, aliases, description, status: active, applies_to, depends_on, supersedes, contradicts_with, tags containing both kind/contract and yoke-framework, project). Create tests/canonical-memory/promoted-concept-frontmatter.test.sh asserting every mandatory field is non-empty. Create fixture under tests/canonical-memory/fixtures/promoted-concept/ with a synthetic cascade candidate per Scenario 3 Given clause.",
    "sensor": "promoted-concept-frontmatter-test",
    "evidence": "cycle-2.yaml exit_code=127. bash: tests/canonical-memory/promoted-concept-frontmatter.test.sh: No such file or directory. sensor file .yoke/sensors/promoted-concept-frontmatter-test.md runs[0..1] both show exit_code=127 — two consecutive misses confirm file has not yet been created."
  },
  {
    "criterion": "FR-5",
    "status": "fail",
    "location": "tests/canonical-memory/promoted-concept-frontmatter.test.sh",
    "fix_instruction": "FR-5 is a subcase of promoted-concept-frontmatter-test. The tags: list in the written concept entity must contain both 'kind/contract' and 'yoke-framework'. Implement as part of the same test file as FR-3 — assert both tag values are present in the tags: YAML field.",
    "sensor": "promoted-concept-frontmatter-test",
    "evidence": "cycle-2.yaml exit_code=127. bash: tests/canonical-memory/promoted-concept-frontmatter.test.sh: No such file or directory — tags subcase never reached."
  },
  {
    "criterion": "FR-4",
    "status": "fail",
    "location": null,
    "fix_instruction": "Three sensors all missing (all exit 127): (1) promoted-concept-backlink-test — create tests/canonical-memory/promoted-concept-backlink.test.sh verifying the actor's ## Recent Activity section contains [[<concept-slug>]] wikilink after write-promoted-concept.sh runs; (2) contract-promotion-bidirectional-self-test — create tests/sensors/contract-promotion-bidirectional.test.sh covering positive/negative/reverse-fixture cases per Scenario 4; (3) contract-promotion-bidirectional-integration — create tests/canonical-memory/contract-promotion-bidirectional-integration.test.sh running lib/sensors/contract-promotion-bidirectional.sh against the Scenario 3 positive fixture. All three depend on lib/canonical-memory/write-promoted-concept.sh and lib/sensors/contract-promotion-bidirectional.sh existing first.",
    "sensor": "promoted-concept-backlink-test",
    "evidence": "cycle-2.yaml: promoted-concept-backlink-test exit_code=127 (No such file or directory); contract-promotion-bidirectional-self-test exit_code=127 (No such file or directory); contract-promotion-bidirectional-integration exit_code=127 (No such file or directory). All three sensors covering FR-4 fail."
  },
  {
    "criterion": "FR-6",
    "status": "fail",
    "location": "tests/canonical-memory/promoted-concept-slug-collision.test.sh",
    "fix_instruction": "Add slug-collision retry logic (up to 5 attempts) to lib/canonical-memory/write-promoted-concept.sh. Create tests/canonical-memory/promoted-concept-slug-collision.test.sh with a fixture pre-seeding concepts/<topic-slug>.md; assert the helper retries and produces a non-colliding slug, and exits non-zero on exhaustion when every retry still collides.",
    "sensor": "promoted-concept-slug-collision-test",
    "evidence": "cycle-2.yaml exit_code=127. bash: tests/canonical-memory/promoted-concept-slug-collision.test.sh: No such file or directory. sensor file .yoke/sensors/promoted-concept-slug-collision-test.md runs[0..1] both show exit_code=127."
  },
  {
    "criterion": "FR-7",
    "status": "fail",
    "location": "tests/canonical-memory/promoted-concept-actor-create.test.sh",
    "fix_instruction": "Add actor-creation logic to lib/canonical-memory/write-promoted-concept.sh (or lib/working-memory/host-actor.sh): when actor entity absent, create it from canonical actor template with well-formed frontmatter per entities/actor.md shape and seed body with backlink. Create tests/canonical-memory/promoted-concept-actor-create.test.sh verifying the actor file is created and the wikilink backlink is present in ## Recent Activity.",
    "sensor": "promoted-concept-actor-create-test",
    "evidence": "cycle-2.yaml exit_code=127. bash: tests/canonical-memory/promoted-concept-actor-create.test.sh: No such file or directory. sensor file .yoke/sensors/promoted-concept-actor-create-test.md runs[0..1] both show exit_code=127."
  },
  {
    "criterion": "FR-9",
    "status": "fail",
    "location": "lib/sensors/ack-sensors.sh",
    "fix_instruction": "ACTIONABLE TOOL-CONTRACT GAP (persisting from cycle 2). The AC sensor command is 'bash lib/sensors/ack-sensors.sh --mode readiness --sensor contract-promotion-bidirectional'; ack-sensors.sh exits 2 with 'Error: unexpected argument: contract-promotion-bidirectional'. Recommended fix: extend lib/sensors/ack-sensors.sh to accept an optional '--sensor <id>' argument that filters readiness output by substring match against the sensor's command path. No AC modification required. This fix was flagged as Generator-owned in cycle-2 verdicts (c1) but was not yet landed. Must be addressed in cycle 3 or 4.",
    "sensor": "contract-promotion-bidirectional-readiness",
    "evidence": "cycle-2.yaml exit_code=2. Error: unexpected argument: contract-promotion-bidirectional. sensor file .yoke/sensors/contract-promotion-bidirectional-readiness.md runs[0].evidence_snippet='Error: unexpected argument: contract-promotion-bidirectional' (cycle 1) AND runs[1].evidence_snippet='Error: unexpected argument: contract-promotion-bidirectional' (cycle 2) — two consecutive identical failures confirm this is not a flake; it is an unimplemented feature in ack-sensors.sh."
  },
  {
    "criterion": "shellcheck-new-scripts",
    "status": "skip",
    "location": null,
    "fix_instruction": "Environmental skip — shellcheck binary not found. Install shellcheck in CI or developer environment. Not a code gap; no Generator action required this cycle.",
    "sensor": "shellcheck-new-scripts",
    "evidence": "cycle-2.yaml exit_code=-1. reason: binary not found: shellcheck. Consistent with cycle-1 skip — environmental constraint."
  }
]
```

## Contract c3 — Cycle 4 Validator verdicts (s01-t03 consensus reached)
- id: "c3"
- topic: "Cycle 4 per-criterion verdicts against cycle-3 snapshot: s01-t03 group confirmed PASS; s01-t04 / FR-9 remain open; slug-summarisation hook pinned as the mechanical realisation of OQ3's resolution"
- decision: "FR-1 / FR-2 / FR-8 / FR-10 / Scenario 1 / Scenario 2 are confirmed PASS (sustained from prior cycles). FR-3 / FR-5 / FR-6 / FR-7 are confirmed PASS (promoted-concept-frontmatter-test, promoted-concept-slug-collision-test, promoted-concept-actor-create-test all exit_code=0 in cycle-3 snapshot). Scenario 3 is confirmed PASS — all 4 of its declared sensors (promoted-concept-frontmatter-test, promoted-concept-backlink-test, promoted-concept-actor-create-test, promoted-concept-slug-collision-test) pass in cycle-3 snapshot. FR-4 is FAIL (any-fail-wins: promoted-concept-backlink-test passes but contract-promotion-bidirectional-self-test exit_code=127 and contract-promotion-bidirectional-integration exit_code=127 — s01-t04 files not yet created). FR-9 is FAIL (contract-promotion-bidirectional-readiness exit_code=2 — ack-sensors.sh --sensor flag still missing; 3 consecutive identical failures across cycles 1-3 confirm this is not a flake; Generator targets this in cycle 4 via s01-t04). Scenario 4 is FAIL (all 3 of its declared sensors map to s01-t04 and all fail: contract-promotion-bidirectional-self-test exit_code=127, contract-promotion-bidirectional-readiness exit_code=2, contract-promotion-bidirectional-integration exit_code=127). shellcheck remains skip (binary absent, environmental). Mechanical interpretation pinned per the consensus instruction: the slug-summarisation hook YOKE_PROMOTED_CONCEPT_SLUG_FN env-override is the mechanical realisation of OQ3's resolution — the test-time stub uses it, the live LLM call uses the default; this refines the AC (Scenario 3 Given: 'When lib/canonical-memory/write-promoted-concept.sh is invoked against a canonical-memory fixture'), does not relax it. Consensus on s01-t03 group is reached."
- rationale: "cycle-3.yaml sensor rows: promoted-concept-frontmatter-test exit_code=0 (runs[2].status=pass in .yoke/sensors/promoted-concept-frontmatter-test.md); promoted-concept-backlink-test exit_code=0 (runs[2].status=pass in .yoke/sensors/promoted-concept-backlink-test.md); promoted-concept-actor-create-test exit_code=0 (runs[2].status=pass in .yoke/sensors/promoted-concept-actor-create-test.md); promoted-concept-slug-collision-test exit_code=0 (runs[2].status=pass in .yoke/sensors/promoted-concept-slug-collision-test.md). All four Scenario 3 sensors pass — any-fail-wins yields PASS for Scenario 3. FR-4 fails under any-fail-wins because two of its three required sensors (contract-promotion-bidirectional-self-test, contract-promotion-bidirectional-integration) both show exit_code=127 (applies_to: s01-t04; runs[0..2] all fail — three consecutive misses confirm these are not flakes but unimplemented files, consistent with Generator's cycle-3 plan noting s01-t04 as out-of-scope). contract-promotion-bidirectional-readiness runs[0..2] all show 'Error: unexpected argument: contract-promotion-bidirectional' (three consecutive fails) — confirmed as an unimplemented feature in ack-sensors.sh, not a flake. The YOKE_PROMOTED_CONCEPT_SLUG_FN pin refines the AC's Scenario 3 interpretation without relaxing any criterion: Scenario 3 requires a 'slug-collision fixture ... retries summarisation up to 5 times'; the env-override hook is the mechanically testable realisation of that retrial contract. The backlink wikilink form [[<concept-slug>]] (bare, no path prefix) is confirmed by promoted-concept-backlink-test subtest output ('actor body uses bare wikilinks (no [[concepts/...]] form)')."
- timestamp: "2026-04-27T23:15:00Z"
- agents_involved: [validation]
- references:
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-1"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-2"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-3"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-4"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-5"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-6"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-7"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-8"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-9"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#FR-10"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#Scenario-1"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#Scenario-2"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#Scenario-3"
    - "acceptance-contracts/2026-04-27-sprint-contract-promotion.md#Scenario-4"
- cycle: 4
- schedule_next:
    sensors:
      - contract-promotion-bidirectional-self-test
      - contract-promotion-bidirectional-integration
      - contract-promotion-bidirectional-readiness
      - promoted-concept-frontmatter-test
      - promoted-concept-backlink-test
      - promoted-concept-actor-create-test
      - promoted-concept-slug-collision-test
      - cascade-occurrences-test
      - semantic-overlap-rewrite-test
    tiers: [cheap]
    reason: "Generator targets s01-t04 in cycle 4: contract-promotion-bidirectional-self-test (runs[0..2].status=fail in .yoke/sensors/contract-promotion-bidirectional-self-test.md — exit_code=127 all three cycles, file not yet created), contract-promotion-bidirectional-integration (runs[0..2].status=fail in .yoke/sensors/contract-promotion-bidirectional-integration.md — exit_code=127 all three cycles), and contract-promotion-bidirectional-readiness (runs[0..2].status=fail — exit_code=2 'Error: unexpected argument: contract-promotion-bidirectional' all three cycles) are the primary verification signals for cycle 4 changes. These three sensors map to FR-4 / FR-9 / Scenario 4 which are the only remaining failing criteria. Regression coverage: promoted-concept-frontmatter-test, promoted-concept-backlink-test, promoted-concept-actor-create-test, promoted-concept-slug-collision-test, cascade-occurrences-test, and semantic-overlap-rewrite-test are scheduled as regression guards because the s01-t04 diff (lib/sensors/contract-promotion-bidirectional.sh + ack-sensors.sh + integration test) could interact with write-promoted-concept.sh output (promoted-concept-* sensors) and the cascade YAML pipeline (cascade / semantic-overlap sensors). No expensive-tier sensors declared in this AC; all sensors are computational cheap-tier. Tier-expensive not authorized — cheap tier was not uniformly green at cycle-3 start (FR-4, FR-9, Scenario 4 still failing) and no diff surface maps to any expensive sensor."

### Verdicts

```json
[
  {
    "criterion": "FR-1",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "cycle-3.yaml exit_code=0. ✓ (1) legacy single-file path emits additive occurrences: 1 only | ✓ (2) single per-task archive emits occurrences: 1 with per-archive traceability | ✓ (3) cross-archive recurrence emits occurrences: 2 with cross-archive traceability (FR-1) | ✓ (3*) cross-archive fixture stdout contains 'occurrences: 2' (binding criterion) | ✓ (4) distinct topics differing by one char remain occurrences: 1 (no coalescing)"
  },
  {
    "criterion": "FR-2",
    "status": "pass",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": null,
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "cycle-3.yaml exit_code=0. ✓ (1) cohesive case emits exactly one merged candidate with occurrences: 2 | ✓ (1*) cohesive merged candidate's reason references both originating contracts (Scenario 2 binding) | ✓ (1**) cohesive case emits no contradiction notes | ✓ (2) split case emits two candidates each with occurrences: 1 and no cohesive group | ✓ (2*) split case emits no contradiction notes"
  },
  {
    "criterion": "FR-3",
    "status": "pass",
    "location": "tests/canonical-memory/promoted-concept-frontmatter.test.sh",
    "fix_instruction": null,
    "sensor": "promoted-concept-frontmatter-test",
    "evidence": "cycle-3.yaml exit_code=0. ✓ (0) helper writes concepts/<slug>.md to canonical-memory dir | ✓ (FR-3) frontmatter field 'type' is non-empty (value: 'concept') | ✓ (FR-3) frontmatter field 'name' is non-empty (value: 'redirectUrl quoting style') | ✓ (FR-3) frontmatter field 'description' is non-empty (value: 'Sprint contract on redirectUrl quoting style') | ✓ (FR-3) frontmatter field 'status' is non-empty (value: 'active'). sensor file .yoke/sensors/promoted-concept-frontmatter-test.md runs[2].status=pass."
  },
  {
    "criterion": "FR-4",
    "status": "fail",
    "location": null,
    "fix_instruction": "Any-fail-wins: promoted-concept-backlink-test passes but contract-promotion-bidirectional-self-test (exit_code=127 — tests/sensors/contract-promotion-bidirectional.test.sh does not exist) and contract-promotion-bidirectional-integration (exit_code=127 — tests/canonical-memory/contract-promotion-bidirectional-integration.test.sh does not exist) both fail. Generator must create: (1) lib/sensors/contract-promotion-bidirectional.sh — the sensor script itself (positive/negative/reverse fixture logic per Scenario 4); (2) tests/sensors/contract-promotion-bidirectional.test.sh — positive fixture exits 0 with empty stdout, negative fixture exits non-zero with structured YAML violation block (id, location, correction_instruction, reference), reverse-fixture exits non-zero; (3) tests/canonical-memory/contract-promotion-bidirectional-integration.test.sh — runs lib/sensors/contract-promotion-bidirectional.sh against the Scenario 3 positive fixture produced by write-promoted-concept.sh and asserts exit 0; also runs against a hand-deleted-backlink fixture and asserts exit non-zero with at least one violation. All are s01-t04 scope.",
    "sensor": "promoted-concept-backlink-test",
    "evidence": "cycle-3.yaml: promoted-concept-backlink-test exit_code=0 (PASS); contract-promotion-bidirectional-self-test exit_code=127 'bash: tests/sensors/contract-promotion-bidirectional.test.sh: No such file or directory' (FAIL); contract-promotion-bidirectional-integration exit_code=127 'bash: tests/canonical-memory/contract-promotion-bidirectional-integration.test.sh: No such file or directory' (FAIL). Any-fail-wins yields FAIL for FR-4. sensor files .yoke/sensors/contract-promotion-bidirectional-self-test.md and .yoke/sensors/contract-promotion-bidirectional-integration.md runs[0..2] all show exit_code=127 — three consecutive misses, not a flake."
  },
  {
    "criterion": "FR-5",
    "status": "pass",
    "location": "tests/canonical-memory/promoted-concept-frontmatter.test.sh",
    "fix_instruction": null,
    "sensor": "promoted-concept-frontmatter-test",
    "evidence": "cycle-3.yaml exit_code=0. promoted-concept-frontmatter-test covers the FR-5 tags subcase (tags: list must contain both 'kind/contract' and 'yoke-framework'). sensor file .yoke/sensors/promoted-concept-frontmatter-test.md runs[2].status=pass confirms full test suite green including tags assertion."
  },
  {
    "criterion": "FR-6",
    "status": "pass",
    "location": "tests/canonical-memory/promoted-concept-slug-collision.test.sh",
    "fix_instruction": null,
    "sensor": "promoted-concept-slug-collision-test",
    "evidence": "cycle-3.yaml exit_code=0. ✓ (FR-6) helper exited non-zero on slug-collision exhaustion (exit: 4) | ✓ (FR-6) slug fn was invoked exactly 5 times (the documented retry cap) | ✓ (FR-6) stderr diagnostic names the colliding slug ('logger-format-choice') | ✓ (FR-6) pre-existing concept file was not clobbered by failed retry | ✓ (FR-6) no actor file was written on the failed retry path. sensor file .yoke/sensors/promoted-concept-slug-collision-test.md runs[2].status=pass."
  },
  {
    "criterion": "FR-7",
    "status": "pass",
    "location": "tests/canonical-memory/promoted-concept-actor-create.test.sh",
    "fix_instruction": null,
    "sensor": "promoted-concept-actor-create-test",
    "evidence": "cycle-3.yaml exit_code=0. ✓ (FR-7) actor file created at <tmpdir>/canonical-memory/actors/brand-new-actor.md | ✓ (FR-7) frontmatter 'type' = 'actor' | ✓ (FR-7) frontmatter 'name' = 'brand-new-actor' | ✓ (FR-7) frontmatter 'status' = 'active' | ✓ (FR-7) frontmatter 'updated_at' is filled (value: '2026-04-27'). sensor file .yoke/sensors/promoted-concept-actor-create-test.md runs[2].status=pass."
  },
  {
    "criterion": "FR-8",
    "status": "pass",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": null,
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "cycle-3.yaml exit_code=0. FR-8 contradiction-subcase covered within semantic-overlap-rewrite-test: contradiction fixture emits top-level notes: entry citing the contradiction AND impact class escalated to require synchronous human ratification (Trigger 5 surface). Full test suite green in cycle-3."
  },
  {
    "criterion": "FR-9",
    "status": "fail",
    "location": "lib/sensors/ack-sensors.sh",
    "fix_instruction": "ACTIONABLE TOOL-CONTRACT GAP (persisting cycles 1-3, now cycle 4). The AC sensor command is 'bash lib/sensors/ack-sensors.sh --mode readiness --sensor contract-promotion-bidirectional'; ack-sensors.sh exits 2 with 'Error: unexpected argument: contract-promotion-bidirectional'. Extend lib/sensors/ack-sensors.sh to accept an optional '--sensor <id>' argument filtering readiness output to sensor entries matching <id> by substring against the sensor's command path. This is s01-t04 scope and must land in the cycle-4 Generator diff.",
    "sensor": "contract-promotion-bidirectional-readiness",
    "evidence": "cycle-3.yaml exit_code=2. 'Error: unexpected argument: contract-promotion-bidirectional'. sensor file .yoke/sensors/contract-promotion-bidirectional-readiness.md runs[0].evidence_snippet='Error: unexpected argument: contract-promotion-bidirectional' (cycle 1), runs[1].evidence_snippet='Error: unexpected argument: contract-promotion-bidirectional' (cycle 2), runs[2].evidence_snippet='Error: unexpected argument: contract-promotion-bidirectional' (cycle 3) — three consecutive identical failures, confirmed not a flake."
  },
  {
    "criterion": "FR-10",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "cycle-3.yaml exit_code=0. Subtest (1) confirms legacy single-file path emits additive occurrences: 1 only — golden output preserved except additive field. FR-10 binding subcase confirmed."
  },
  {
    "criterion": "Scenario 1",
    "status": "pass",
    "location": "tests/canonical-memory/cascade-occurrences.test.sh",
    "fix_instruction": null,
    "sensor": "cascade-occurrences-test",
    "evidence": "cycle-3.yaml exit_code=0. All 5 Scenario 1 subcases confirmed: occurrences: 2 cross-archive, occurrences: 1 distinct-topic isolation, legacy golden path, single-archive traceability, and performance <5s."
  },
  {
    "criterion": "Scenario 2",
    "status": "pass",
    "location": "tests/canonical-memory/semantic-overlap-rewrite.test.sh",
    "fix_instruction": null,
    "sensor": "semantic-overlap-rewrite-test",
    "evidence": "cycle-3.yaml exit_code=0. All Scenario 2 binding subcases confirmed: cohesive emits occurrences: 2 with reason referencing both originating contracts; split emits two occurrences: 1 candidates; contradiction emits notes: block with escalation signal; no-invent invariant upheld."
  },
  {
    "criterion": "Scenario 3",
    "status": "pass",
    "location": "lib/canonical-memory/write-promoted-concept.sh",
    "fix_instruction": null,
    "sensor": "promoted-concept-frontmatter-test",
    "evidence": "cycle-3.yaml: all 4 of Scenario 3's declared sensors pass. promoted-concept-frontmatter-test exit_code=0 (FR-3 + FR-5 binding fields confirmed); promoted-concept-backlink-test exit_code=0 (FR-4 backlink subcase: actor ## Recent Activity contains bare wikilink [[<concept-slug>]], no [[concepts/...]] form); promoted-concept-actor-create-test exit_code=0 (FR-7: actor created from template on absent-actor fixture with well-formed frontmatter); promoted-concept-slug-collision-test exit_code=0 (FR-6: 5-attempt retry cap honoured, exits non-zero on exhaustion). Any-fail-wins over 4 sensors yields PASS. Mechanical interpretation pinned: YOKE_PROMOTED_CONCEPT_SLUG_FN env-override is the mechanical realisation of OQ3's resolution — test-time stub uses it, live LLM call uses the default; refines AC Scenario 3, does not relax it."
  },
  {
    "criterion": "Scenario 4",
    "status": "fail",
    "location": null,
    "fix_instruction": "All 3 of Scenario 4's declared sensors fail: contract-promotion-bidirectional-self-test exit_code=127 (tests/sensors/contract-promotion-bidirectional.test.sh not yet created); contract-promotion-bidirectional-readiness exit_code=2 (ack-sensors.sh --sensor flag missing); contract-promotion-bidirectional-integration exit_code=127 (tests/canonical-memory/contract-promotion-bidirectional-integration.test.sh not yet created). Generator must complete s01-t04: create lib/sensors/contract-promotion-bidirectional.sh, extend lib/sensors/ack-sensors.sh with --sensor filtering, create both test files, and create the fixture directory at tests/sensors/fixtures/contract-promotion-bidirectional/ per the AC Fixture declaration.",
    "sensor": "contract-promotion-bidirectional-self-test",
    "evidence": "cycle-3.yaml: contract-promotion-bidirectional-self-test exit_code=127 'bash: tests/sensors/contract-promotion-bidirectional.test.sh: No such file or directory'; contract-promotion-bidirectional-readiness exit_code=2 'Error: unexpected argument: contract-promotion-bidirectional'; contract-promotion-bidirectional-integration exit_code=127 'bash: tests/canonical-memory/contract-promotion-bidirectional-integration.test.sh: No such file or directory'. sensor files runs[0..2] confirm three consecutive failures on all three sensors."
  },
  {
    "criterion": "shellcheck-new-scripts",
    "status": "skip",
    "location": null,
    "fix_instruction": "Environmental skip — shellcheck binary not found. Install shellcheck in CI or developer environment. Not a code gap; no Generator action required this cycle.",
    "sensor": "shellcheck-new-scripts",
    "evidence": "cycle-3.yaml exit_code=-1. reason: binary not found: shellcheck. Consistent with cycles 1-3 skip — environmental constraint."
  }
]
```
