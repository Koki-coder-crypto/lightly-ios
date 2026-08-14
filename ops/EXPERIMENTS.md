# SnapInbox experiment ledger

Run at most three experiments per calendar week and change one variable per experiment. A result is **undecided** until it has at least five attributed first-time downloads and 72 hours have elapsed.

| ID | Status | Variable | Variant A | Variant B | Primary metric | Guardrail | Start | Review | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EXP-001 | planned | Onboarding sequence | Explain the screenshot inbox before photo permission | Ask for photo permission immediately | First screenshot review completed per download | Photo-access denial rate | — | — | — |
| EXP-002 | backlog | Video hook | “3,000 screenshots” | “Deleting screenshots feels risky” | Campaign product-page views per first-time download | Misleading-claim reports | — | — | — |
| EXP-003 | backlog | Paywall value | Weekly inbox | Review later | Download-to-paid conversion | Refund rate | — | — | — |

## Rules

- Record the campaign token for every content experiment in `ops/CONTENT_QUEUE.md`.
- Keep winners; revert losers; leave undecided variants in place until their review threshold is met.
- Pause all growth experiments and fix any crash, deletion, purchase, restore, or accessibility issue first.
