# SnapInbox operating state

## Current focus

- **Product:** SnapInbox — a private inbox for screenshots that need a decision.
- **Market:** English-language TikTok as the primary acquisition experiment; App Store English (U.S.) is the primary product page.
- **Current hypothesis:** People with recurring screenshot clutter will return for a weekly, safe review when they can defer a screenshot instead of deleting it immediately.
- **Experiment:** EXP-001 (onboarding value message vs. direct permission request).
- **Owner:** Codex for research, implementation, test, asset generation, and queued distribution; account holder for OAuth, API audits, App Store submission, and legal/financial settings.

## Guardrails

- Only one experiment may change product behavior at a time.
- Do not publish external content until the platform API is approved and credentials are configured outside the repository.
- Do not alter subscription prices without a completed experiment record and account-holder approval.

## Next safe actions

1. Build and verify the renamed SnapInbox simulator target.
2. Test screenshot defer/review behavior on a physical device.
3. Complete EXP-001 before making another onboarding change.
4. Create App Store campaign links for each content experiment after the app record exists.
