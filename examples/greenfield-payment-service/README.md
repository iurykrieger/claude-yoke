# Example: greenfield-payment-service

A worked end-to-end example of running the full Yoke flow against a
fresh Node.js project. Used as the v1.0 reference example; also exercised
by `tests/smoke/sprint-8.test.sh`.

## What this example demonstrates

A tiny payment-reversal service ("reverse a payment by `tx_id`, refunding
to the originating instrument"). The example carries the **artifacts**
of a completed Yoke task — a PRD, Tech Spec, and ratified Acceptance
Contract — but **not** the final implementation code. The point is to
show what `.yoke/` looks like after Phase 3, ready for `/yoke:implement`.

## Files

```
greenfield-payment-service/
├── README.md                      ← you are here
├── CLAUDE.md                      ← discoverable sensors (## Testing / Linting / Build)
└── .yoke/
    ├── config.yaml                ← bootstrap output
    ├── prd.md                     ← Phase 1 — approved
    ├── tech-spec.md               ← Phase 2 — approved
    └── acceptance-contract.md     ← Phase 3 — ratified (binding)
```

## Walking through it

> The example assumes the Yoke plugin is installed and `gh` is
> authenticated. See `docs/installation.md` in the plugin repo.

```bash
cd examples/greenfield-payment-service

# Inspect the artifacts
cat .yoke/prd.md             # what we are building, why
cat .yoke/tech-spec.md       # how we are building it (sprints + tasks)
cat .yoke/acceptance-contract.md  # how we know it's done (binding)

# Drive Phase 4
/yoke:implement              # spawns Implementation + Validation Agents

# After convergence
/yoke:canonize               # propose canonical-memory writes (low-impact only)
```

Expected wall-clock for a full run: **< 30 minutes** on a clean test
environment (per Sprint-8 DoD #1).

## How to read the example artifacts

- **`prd.md`** — Phase-1 shape: product invariants, business context,
  known constraints (technical / regulatory / organizational), risks,
  open questions. Status: `approved`.
- **`tech-spec.md`** — Phase-2 shape: sprints with delivery objectives;
  each task is a use case with a binary, observable acceptance
  criterion; contracts and dependencies. Status: `approved`.
- **`acceptance-contract.md`** — Phase-3 shape: binding statement, BDD
  scenarios per task, FRs, applicable policies (PCI-DSS, LGPD), declared
  sensors (computational + inferential placeholders). Status: `ratified`.

## What this example does NOT include

- The actual TypeScript / Node implementation. Run `/yoke:implement` to
  drive its creation against the binding Contract.
- A populated canonical-memory repo. The `canonical_memory.url` in
  `.yoke/config.yaml` points at a placeholder; the
  `docs/canonical-memory-setup.md` walkthrough creates a real one for
  you.
- Production deployment hooks. Yoke v1.0 stops at "merge-ready code".
