# Caliqo TestFlight CI Setup

The `iOS` workflow builds every pull request and can archive/upload on manual dispatch with `upload_testflight=true`.

Required repository secrets for upload:

- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64`
- `APPLE_TEAM_ID`
- `PROFILE_NAME` (must match `Caliqo AppStore CI` in `ci/ExportOptions.plist`)
- `APPSTORE_KEY_ID`
- `APPSTORE_ISSUER_ID`
- `APPSTORE_PRIVATE_KEY`

The distribution profile must be for `jp.egawa.caliqo`. The certificate, profile, API key, and app record must be created by the Apple Developer/App Store Connect account owner before TestFlight upload can succeed.
