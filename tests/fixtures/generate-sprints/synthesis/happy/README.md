# Synthesis happy-path fixture

Used by Sr QA's `us-004-synthesis-us-coverage.test.sh` and
`us-004-realizes-array-shape.test.sh`. Carries exactly 4 User Stories
(US-001..US-004); the synthesis stage MUST emit ≥4 tasks where every
US appears in at least one task's `realizes_user_stories` array.
