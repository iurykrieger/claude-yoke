# Template: Approval menu (shared shape for blocking gates)

> Shared menu shape rendered at the end of the three blocking-gate skills:
> `/yoke:discover` (Trigger 1), `/yoke:tech-spec` (Trigger 2),
> `/yoke:acceptance-contract` (Trigger 3). Triggers 4 and 5 are explicitly
> **excluded** from this template — see `concepts/yoke-pattern-human-triggers`
> ("coalescing triggers is an anti-pattern").
>
> Status: Trigger 1 adopts this template in Yoke v0.x (Spec
> `plan-options-part-1`). Triggers 2 and 3 adopt it in `plan-options-part-2`.

## Purpose

Replace the trailing free-text "Run `/yoke:<next>` to advance" instruction
that today closes each blocking gate with a structured 4-option prompt.
The menu is a **deterministic surface**, not an agentic node — the host
skill renders it verbatim and parses the user's response by digit.

## Inputs (passed in by the host skill)

- `artifact_path` — relative path of the artifact under review
  (e.g. `.yoke/prd.md`).
- `artifact_label` — human-readable name (e.g. `PRD`, `Tech Spec`,
  `Acceptance Contract`). Used in option labels and warnings.
- `next_skill` — slash-command identifier of the next-phase skill
  (e.g. `/yoke:tech-spec`). Empty string disables option 1's chained
  behavior — the option falls back to "approve only".
- `language` — detected user language code (e.g. `en`, `pt`, `es`). The
  host skill passes whatever it detected for the dialogue itself.
- `binding_statement` — optional verbatim block printed **before** the
  open-questions block when the gate carries binding semantics
  (Trigger 3 — Acceptance Contract). Empty for Triggers 1 and 2.
- `task_summary` — optional ordered list of per-task tuples (one per
  task file) used **only** by `/yoke:tech-spec` (Trigger 2) when
  rendering the Tech-Spec-only block. Each entry is the triple
  `(task_id, one-line story, file path)`. The host skill builds this
  list from `wm_list_task_paths "$slug"` after stage 3 has filled
  every task file's `# Task <id> — <story>` heading. Empty / unset
  for Triggers 1 and 3.

## Output (returned to the host skill)

A single internal verb plus optional payload:

| Verb | Payload | Meaning |
| :--- | :--- | :--- |
| `approve_and_continue` | — | Record approval, then chain into `next_skill`. Subject to the open-questions confirmation below. |
| `approve` | — | Record approval. Stop. |
| `reject` | — | Treat as not-approved (no `Status: approved` written). Triggers a secondary prompt offering re-run. |
| `revise` | `<feedback>` (multi-line, terminated by a blank line) | Loop back to the same skill's Generator/Validator iteration with the feedback as input. |

**Internal verbs are stable English identifiers and MUST NOT be
translated.** Localization happens at the label layer (see Rendering).

## Rendering order

The host skill renders these blocks in order, every time:

1. **Binding statement** (only when `binding_statement` is non-empty).
2. **Tech-Spec-only per-task summary** (only when `artifact_label`
   equals `Tech Spec` and `task_summary` is non-empty — see
   "Tech-Spec-only block" below).
3. **Open / unresolved items** block — see Detection rule below.
4. **The 4-option prompt.**

### Tech-Spec-only block

Rendered only by `/yoke:tech-spec` (Trigger 2) when
`task_summary` carries entries — i.e., when stages 1–3 of the
3-stage blueprint have produced both the spec and the per-task
files. Triggers 1 and 3 explicitly do not render this block; the
condition is `artifact_label == "Tech Spec"` (every other host
passes a different `artifact_label` and hence skips this block).
Forking the template per trigger is the anti-pattern called out in
`concepts/yoke-pattern-human-triggers` ("shape is shared, semantics
are distinct"); a conditional block honors that rule because the
condition fires on input shape, not on trigger semantics.

When the condition is met, render exactly:

```
### Tasks scheduled for approval (N)

- <task_id_1> — <story_1>  (<file_path_1>)
- <task_id_2> — <story_2>  (<file_path_2>)
…
```

`N` is the count of `task_summary` entries. The list is the verbatim
order returned by `wm_list_task_paths "$slug"` (= positional order
via the `s<NN>-t<MM>` filename suffix).

The block surfaces what the user is approving in one decision —
without it, Trigger 2 would conceal the per-task contents under a
single spec-level approval. The `Open / unresolved items` block that
follows scans the spec **and** every task file referenced in
`task_summary`, so unresolved markers anywhere in the sprint set
surface together.

### Detection rule (for the open-questions block)

Scan the artifact body at `artifact_path` for unresolved markers. The
detection is a deterministic textual scan, not an LLM judgment:

- **Section scan.** If the artifact contains a heading matching
  `## Open questions` (case-insensitive) followed by non-empty body
  content (anything other than the literal word `None.` or an empty list),
  treat each non-empty bullet/line under that heading as an unresolved
  item.
- **Inline-marker scan.** Within the artifact body, match these tokens:
  - `TODO:` (followed by any text on the same line)
  - `TBD` (whole word)
  - `FIXME:` (followed by any text on the same line)
  - `<[^>]+>` placeholders (angle-bracket spans in body text)
- **De-duplication.** If the same line matches more than one rule, count
  it once.

If at least one unresolved item is detected, render the block:

```
### Open / unresolved items (N)

- <line excerpt 1>
- <line excerpt 2>
…
```

If zero items are detected, render `### Open / unresolved items: none`
inline (one line, no list). The block is rendered **every time** —
visibility of "none" is part of the contract.

The detected count `N` is reused by the warning confirmation below.

### The 4-option prompt

Render verbatim, preserving option order. Labels are translated to the
detected language; the digit and the internal verb are stable:

```
**<artifact_label> ready.** What now?

1. **Approve & continue** — record approval and advance to <next_skill>
2. **Approve** — record approval and stop here
3. **Reject** — discard this draft (you'll be asked once more before discarding)
4. **Other / revise** — type your feedback (end with a blank line)

Reply with `1`, `2`, `3`, or `4`.
```

If `next_skill` is empty, render option 1 as `**Approve** — record approval`
(same effect as option 2) and add a footnote: `(no next phase configured)`.
This is the fallback path; see Fallback below.

## Decision branches

### `1` — `approve_and_continue`

1. Compute `N` from the detection rule above.
2. **If `N > 0`:** print the warning confirmation:

   ```
   ⚠ <N> open / unresolved item(s) detected. Continuing will start the
   next phase with these still pending. Proceed?

   Reply `yes` to continue and chain into <next_skill>, or `no` to record
   approval and stop here.
   ```

   - Reply `yes` → record approval, then invoke `next_skill` via the
     `Skill` tool in the same turn (chained execution).
   - Reply `no` → record approval, do **not** chain. Behaves like option
     2 from this point on.
3. **If `N == 0`:** record approval and chain into `next_skill` immediately.

### `2` — `approve`

Record approval. Stop. The host skill exits cleanly. Today's
trailing-instruction line is suppressed — option 2 is the new equivalent
of "approve and let the user advance manually."

### `3` — `reject`

Print a single secondary confirmation:

```
Rejecting will discard this draft. Are you sure? Reply `yes` to discard,
or `no` to keep the draft and re-render this menu.
```

- Reply `yes` → mark the artifact rejected (no `Status: approved` is
  written) and exit cleanly. Subsequent runs treat the artifact as a
  fresh start.
- Reply `no` → re-render the menu from step 1 of the Rendering order.

### `4` — `revise`

Print a single line: `Type your feedback. End with a blank line.` Read
multi-line input until the user submits a blank line. Pass the captured
text back to the host skill's Generator/Validator iteration loop. Today's
`revise <feedback>` semantics are preserved verbatim.

## Recording approval

On `approve` and `approve_and_continue`, the host skill writes the
artifact's existing approval metadata (today: `Status: approved`,
`Approved by`, `Approved at`). This template **does not** change
metadata semantics — it only changes how the user reaches the approval
decision.

## Fallback (Skill tool unavailable)

If the runtime does not expose the `Skill` tool (some Claude Code
versions or non-Claude harnesses), option 1's chained invocation is not
possible. The host skill MUST detect availability before rendering and:

- Render option 1 with the suffix `(manual: run <next_skill> after this
  step)`.
- On selection of option 1, record approval and print the same line the
  pre-template skill printed today (`<artifact_label> approved. Run
  <next_skill> to advance.`), then exit cleanly.

This guarantees no degraded path: the menu is always rendered, the user
always picks the same digit, but the chained execution gracefully
collapses to today's manual behavior.

## Localization

The host skill detects the user's language and passes it as `language`.
Labels in the 4-option prompt, the warning confirmation text, and the
`reject` secondary confirmation are translated to that language. Internal
verbs (`approve_and_continue`, `approve`, `reject`, `revise`), digit
keys (`1`–`4`), and option-1 chained-skill semantics are stable and
**never translated**.

If `language` is unknown, render in English as the default.

## Anti-scope

- This template MUST NOT be used by `/yoke:implement` (Trigger 4) or
  `/yoke:canonize` (Trigger 5). Those triggers carry distinct decision
  spaces (4-way arbitration; Model C contextual authority) that do not
  fit the 4-option shape. Coalescing them is an anti-pattern documented
  in `concepts/yoke-pattern-human-triggers`.
- This template does not record audit-log entries directly. Each blocking
  gate retains its own audit log surface; the menu is purely the
  user-facing prompt.
- This template introduces no new agentic node — it is a rendered surface
  parsed deterministically by the host skill.
