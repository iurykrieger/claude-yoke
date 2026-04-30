---
id: existing-curated
type: computational
token_cost: 0
time_cost: 30
command: bash -c 'echo curated; true'
---

# existing-curated

## How to run

Author-curated invocation: `bash -c 'echo curated; true'`. The body
text below is hand-written and MUST survive upsert byte-identical.

## Known issues

- Times out under 30s on cold DB; warm with `make seed-test-db`.
- macOS-only — uses GNU `find -printf` flag.

## Frequent errors

- Missing trailing newline on YAML frontmatter: append `\n` before save.
- Tab indentation inside YAML block: convert to two spaces.

