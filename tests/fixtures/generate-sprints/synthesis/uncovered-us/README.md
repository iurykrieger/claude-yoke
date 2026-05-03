# Synthesis uncovered-US fixture

Engineered to make US-003 non-realizable: its DoD anchors on a
"Phantom subsystem" architecture section that does NOT appear in
`spec.md`. The synthesis stage MUST detect the orphan and abort with
exactly:

```
wm: unrealized USs: US-003
```

Used by `us-004-uncovered-us-rejection.test.sh`.
