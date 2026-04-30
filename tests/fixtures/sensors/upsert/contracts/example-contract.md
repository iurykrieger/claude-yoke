# Acceptance Contract — upsert fixture

> Synthetic contract used by the upsert fixture; references three
> sensor ids: one already on disk (curated), two missing.

## Use cases (BDD scenarios)

### Scenario 1 — curated sensor passes
Task: upsert-fixture-s01-t01
Given the curated sensor file exists on disk with author content
When upsert runs
Then the existing file is byte-identical to its snapshot
Sensors: [existing-curated]

### Scenario 2 — new sensor materializes
Task: upsert-fixture-s01-t02
Given the contract references `new-sensor` but no file exists on disk
When upsert runs
Then `sensors/new-sensor.md` is created from the template with `type:` populated
Sensors: [new-sensor]

## Functional requirements

### Criterion FR-A — curated content survives upsert

The author-curated bullet under `## Known issues` of the existing
sensor file must NOT be modified by upsert.

### Validation

- **existing-curated** — pass = curated bullet preserved verbatim post-upsert; fail = upsert mutated the file.

### Criterion FR-B — new sensor is materialized

The contract reference to `new-sensor` must produce a freshly
rendered sensor file.

### Validation

- **new-sensor** — pass = `sensors/new-sensor.md` exists and contains `type:`; fail = file missing or schema invalid.
