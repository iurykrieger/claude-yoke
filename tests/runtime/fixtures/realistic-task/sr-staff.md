---
author: sr-staff
cycle: 0
phase: a
slug: 2026-05-01-realistic-task
---

# Sr Staff — Phase A slice (realistic-task fixture)

## Phase A — own progress

### Review output

(verbatim output of the configured `review-skill`, default `/review`,
invoked exactly once against the cycle's diff)

```
/review verdict: heading-hierarchy.sh introduces a parsing branch that
duplicates the markdown-parsing helper logic shipped at
lib/working-memory/migration-helpers.sh::parse_headings. Recommend
factoring the parser into a shared helper before this surface
acquires a third caller; otherwise the dual-implementation will drift.
Severity: clarification needed (not blocking on this cycle).
```

### Canonical-memory queries

- /yoke:search-canonical-memory query: "what does Yoke decide about computational sensor structure?"
  response_summary: "concepts/yoke-pattern-sensors — every computational sensor must (a) live under .yoke/sensors/<id>.md, (b) emit a wm-prefixed structured violation on failure, (c) be wired into one or more `### Validation` blocks; concepts/yoke-conventions — the `wm: <sensor-id> violation: <reason>` shape is non-negotiable"
  decision_appears_violated: false (the sensor honours both decisions; Sr QA already flagged the message-shape PARTIAL on one branch)

- /yoke:search-canonical-memory query: "is there a ratified markdown-parsing helper in this codebase?"
  response_summary: "lib/working-memory/migration-helpers.sh ships a heading-parser introduced by the doctrine-canonization PRD; concepts/yoke-pattern-plugin-structure does NOT mandate factoring but the convention favours single helper per parsing concern"
  decision_appears_violated: false (no ratified MUST is being violated; the duplication is a sustainability concern, not a doctrine breach)

### Architectural assessment

- longevity: the sensor will hold N sprints from now provided the
  message-shape PARTIAL Sr QA flagged is closed; without that, the
  message-shape drift compounds across future sensors.
- coupling: low — the sensor reads markdown only and writes nothing;
  no new cross-module coupling introduced.
- future-extensibility: medium concern — duplicating the heading
  parser closes off the natural extension point of the existing
  helper. A third caller would land before anyone notices the
  duplication.
- pattern-alignment: aligned with `concepts/yoke-pattern-sensors`;
  diverges (informally, no MUST) from the parsing-helper convention
  surfaced by the second canonical-memory query.
- sustainability: clarification needed — refactor the parser into
  the shared helper before the third caller lands.

verdict: clarification needed — the sensor ships and closes the cited
criterion (good enough for this cycle), but the parser duplication
should be tracked as a follow-up. Citation: concepts/yoke-pattern-sensors,
lib/working-memory/migration-helpers.sh.

## Phase B — réplicas

(empty in this engineered fixture; the irreducibility test only inspects Phase-A shape)
