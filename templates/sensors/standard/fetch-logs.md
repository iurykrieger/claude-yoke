---
id: fetch-logs
type: computational
token_cost: 0
time_cost: 30
command: <DISCOVER>
---

# fetch-logs

Standard sensor — fetches recent runtime logs / observability
output. The `command:` field is resolved at
`/yoke:ack-sensors --mode bootstrap` time via the discover-from
chain:

  1. CLAUDE.md `## Logs` / `## Observability` section (first
     backticked command).
  2. package.json `scripts.logs` or `scripts.tail`.
  3. Makefile `logs:` target.
  4. Fallback: tail the last 200 lines of the most recent file
     under `logs/` or `var/log/` if either exists; otherwise no-op
     `echo "logs: no log source declared"; exit 0`.

The sensor surface is intentionally loose because log sources vary
wildly (stdout capture, structured logs, observability vendors,
journalctl, container runtime logs, application-emitted JSON, …).
Specialize the file by hand for the project's actual log path.

## How to run

`bash -c "$(awk '/^command:/{sub(/^command:[[:space:]]*/,""); print}' .yoke/sensors/fetch-logs.md)"`

For projects with vendor observability (Grafana, Datadog, Vercel
runtime logs), the wrapper SHOULD `curl` the vendor API with a
project-scoped token (declared in `.yoke/config.yaml`) rather than
shipping the token into the sensor file. Treat the sensor file's
`command:` as the dispatch verb; treat secrets as out-of-band.

## Known issues

- The sensor may pass even when no logs are produced (silent
  failure mode). The dependent criterion's `### Validation` should
  assert log content (e.g., `expect: 'no ERROR lines in last 200'`),
  not just sensor exit 0.
- Log rotation can cause false negatives: the wrapper should fall
  back to the previous rotated file when the live one is empty.

## Frequent errors

- wrapper-greps-stale-log-path: refresh the path in CLAUDE.md when the project changes its log layout.
- wrapper-exits-0-on-missing-log-file: change `||` to `&&` so a missing file fails fast.
