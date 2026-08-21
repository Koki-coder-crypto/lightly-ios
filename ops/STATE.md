# SnapInbox operating state

## Current focus

- **Product:** SnapInbox — a private inbox for screenshots that need a decision.
- **Market:** English-language TikTok as the primary acquisition experiment; App Store English (U.S.) is the primary product page.
- **Current hypothesis:** People with recurring screenshot clutter will return for a weekly, safe review when they can defer a screenshot instead of deleting it immediately.
- **Experiment:** EXP-001 (onboarding value message vs. direct permission request).
- **Owner:** Codex for research, implementation, tests, commits, CI, TestFlight/App Store Connect work permitted by configured credentials, asset generation, and queued distribution. The account holder is needed only for interactive OAuth/audit approval, platform terms, identity, payment, tax, or legal settings.

## Product decision — 2026-08-21 JST

- **Selected experiment:** EXP-001 is the only active product experiment.
- **Frozen:** price, paywall, subscription configuration, product-page copy, notifications, categorization, bulk actions, and all R-001–R-003 candidates.
- **Permitted implementation:** only the onboarding sequence needed to compare an explanation before photo permission against direct photo permission, with no change to deletion behavior.

## Guardrails

- Only one experiment may change product behavior at a time.
- Do not publish external content until the platform API is approved and credentials are configured outside the repository.
- Do not alter subscription prices without a completed experiment record and account-holder approval.

## Next safe actions

1. Sign in to App Store Connect in the shared browser session, then complete the remaining App Review gates for build 1.0.0 (1).
2. Re-run the screenshot capture workflow only after store-sign-in release work is complete; it now skips the unsupported precheck and replaces, rather than duplicates, existing screenshots.
3. Build and verify the renamed SnapInbox simulator target.
4. Test screenshot defer/review behavior on a physical device.
5. Complete EXP-001 before making another onboarding change.
6. Create App Store campaign links for each content experiment after the app record exists.
