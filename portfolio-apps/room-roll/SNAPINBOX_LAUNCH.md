# SnapInbox launch brief

## Product promise

SnapInbox turns screenshots into a small, private review inbox. A person can keep a screenshot, stage it for deletion, or defer the decision for seven days. It never uploads media and never deletes anything without the person's final iOS confirmation.

## Day-21 minimum release scope

- Screenshot-only review home.
- Keep, staged delete, and seven-day defer decisions.
- A final, reversible deletion confirmation.
- Free monthly allowance and an optional subscription for unlimited reviews.
- Japanese and English App Store listings, privacy policy, support URL, and a physical-device permission test.

## Store listing draft

| Locale | Name | Subtitle |
| --- | --- | --- |
| Japanese | SnapInbox | スクショを、あとで迷わず整理 |
| English (U.S.) | SnapInbox: Screenshot Organizer | Review screenshots without losing them |

**English description**

SnapInbox gives screenshots a calm inbox instead of treating them as clutter. Review each screenshot on your device and choose to keep it, stage it for deletion, or defer it for a later review. Nothing is uploaded or removed automatically. Before a deletion, iOS asks for confirmation and moves selected items to Recently Deleted.

## Release gate

Before TestFlight or App Store submission, record the test date and result in `ops/EXPERIMENTS.md`. A build must pass the GitHub Actions simulator build and be checked on a physical iPhone for permission denial, limited-library mode, defer/undo, staged deletion, and subscription restore.
