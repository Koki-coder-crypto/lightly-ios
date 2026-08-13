# Portfolio Apps — TestFlight upload setup

`Portfolio TestFlight` builds and uploads exactly one selected app. It supports FrameDrop, QR Keeper, Handy Print, Meeting Spark, Focus Pocket, Warranty Ledger, Leave Check, Receipt Split, Parcel Note, Wi-Fi Notes, and Home Care.

## One-time repository secrets

Configure these repository secrets once, using an Apple Distribution certificate and an App Store Connect API key that can create App IDs, profiles, and app records:

- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `APPLE_TEAM_ID`
- `APPSTORE_KEY_ID`
- `APPSTORE_ISSUER_ID`
- `APPSTORE_PRIVATE_KEY`

The workflow creates the selected App ID, App Store Connect record, and an App Store distribution profile when they do not already exist. It does not store a profile in the repository.

## Before each first upload

1. In App Store Connect, create the monthly and yearly subscription products listed in the app's `APP_STORE_SUBMISSION.md`, including prices and trial terms.
2. Complete the app's localization, App Privacy answers, support URL, privacy-policy URL, screenshots, and review notes.
3. Run the `Portfolio iOS` workflow and confirm the selected app's simulator build passes.

## Upload

Open **Actions → Portfolio TestFlight → Run workflow**, select one app, and run it. The workflow uploads only to TestFlight; it does not submit the app for App Review or make it public.

After Apple finishes processing the build, complete the Sandbox purchase and restore test, then submit the version from its App Store Connect page.
