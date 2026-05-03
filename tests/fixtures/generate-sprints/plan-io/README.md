# Fixtures: plan-io

Empty placeholder directory for tmp-staging tests of
`lib/generate-sprints/plan-io.sh`. The companion test
`tests/acceptance/2026-05-03-generate-sprints-skill/us-003-plan-yaml-init.test.sh`
creates its own `mktemp -d` host root; this directory is reserved
for future fixture-based assertions (e.g. read-only-FS-error path
documented in s02-t04 validation).
