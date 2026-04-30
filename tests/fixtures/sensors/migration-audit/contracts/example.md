# Acceptance Contract — migration-audit fixture

> Synthetic contract used by the migration-audit fixture. References
> two sensor ids (`keep-1`, `keep-2`) that exist in the catalog; the
> catalog also carries three unreferenced ids (`delete-1`, `orphan-1`,
> `orphan-2`) that the audit must classify as orphan-candidate.

## Functional requirements

### Criterion FR-A — keep-1 holds

### Validation

- **keep-1** — pass = sensor green; fail = sensor red.

### Criterion FR-B — keep-2 holds

### Validation

- **keep-2** — pass = sensor green; fail = sensor red.
