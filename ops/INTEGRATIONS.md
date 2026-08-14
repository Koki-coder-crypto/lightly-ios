# Content publishing integration gate

## Current status

| Channel | Status | Permitted automated action |
| --- | --- | --- |
| YouTube Shorts | credentials and OAuth audit not configured | prepare original video, title, description, and campaign URL only |
| TikTok | credentials and Direct Post audit not configured | prepare original video, caption, and campaign URL only |

## Required approval before publishing

1. Create a developer application using the account that owns the channel.
2. Configure OAuth redirect URLs and store credentials only in the operating system credential store or GitHub/Codex secrets; never commit them.
3. Complete the provider's required audit for public posting.
4. Run a test upload to the owner's test account and verify visibility, attribution link, caption, and analytics.
5. Change this table to `approved`, record the approver/date, and only then permit an automation to publish a queued item.

## Campaign attribution

Every queued asset receives its own Apple campaign token before publication. Record the token, posted URL, platform, timestamp, and 72-hour result in `ops/EXPERIMENTS.md`. Never reuse a token for a different creative.

## Content rules

- Record observations from successful content as problem, first-three-second hook, pacing, captions, CTA, and unmet user need.
- Make each visual, recording, subtitle, script, and soundtrack from scratch for SnapInbox.
- Do not reproduce a competitor's name, screen, wording, asset, audio, or edit sequence.
- Do not publish a claim that cannot be demonstrated in the current app build.
