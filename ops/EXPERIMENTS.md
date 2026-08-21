# SnapInbox experiment ledger

Run at most three experiments per calendar week and change one variable per experiment. A result is **undecided** until it has at least five attributed first-time downloads and 72 hours have elapsed.

| ID | Status | Variable | Variant A | Variant B | Primary metric | Guardrail | Start | Review | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EXP-001 | active | Onboarding sequence | Explain the screenshot inbox before photo permission | Ask for photo permission immediately | First screenshot review completed per download | Photo-access denial rate | — | — | Active; all unrelated changes frozen 2026-08-21 JST |
| EXP-002 | backlog | Video hook | “3,000 screenshots” | “Deleting screenshots feels risky” | Campaign product-page views per first-time download | Misleading-claim reports | — | — | — |
| EXP-003 | backlog | Paywall value | Weekly inbox | Review later | Download-to-paid conversion | Refund rate | — | — | — |

## Rules

- Record the campaign token for every content experiment in `ops/CONTENT_QUEUE.md`.
- Keep winners; revert losers; leave undecided variants in place until their review threshold is met.
- Pause all growth experiments and fix any crash, deletion, purchase, restore, or accessibility issue first.

## Research — 2026-08-21 JST

Source review of public App Store listings and user feedback was limited to problem patterns and unmet needs; no names, copy, assets, or interaction sequences were reused.

- Observation: Users value a separate review space because screenshots obscure personal photos; frequent failures concern freezes, incomplete import, and unreliable batch actions.
- Observation: Reviewers respond to the ability to defer a decision, but the deletion action must remain visibly safe and under the user's control.
- Hypothesis R-001: Showing one reversible **Review later** action before the first deletion option will increase first-review completion without increasing photo-access denials. Candidate follow-up to EXP-001 only.
- Hypothesis R-002: Showing progress as **a small, finite first batch** will reduce abandonment compared with presenting the full screenshot library immediately. Backlog; do not combine with EXP-001.
- Hypothesis R-003: A factual on-device/privacy explanation placed beside the first deletion action will improve delete-intent completion while keeping accidental-deletion reports at zero. Backlog; safety review required before testing.
