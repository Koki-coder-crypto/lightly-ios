# App Store Connect Setup: Caliqo

Create the app record with these values:

- Name: Caliqo: AR Measure and Level
- Bundle ID: `jp.egawa.caliqo`
- SKU: `caliqo-ios-001`
- Category: Utilities
- Age rating: 4+
- Primary language: English (U.S.)

Copy the text in `STORE_LISTING.md` into the App Store record. Publish `site/index.html`, `site/support.html`, and `site/privacy.html` before entering the support and privacy URLs.

App Privacy declaration: Data Not Collected. The camera is used only by ARKit to find surfaces and distances. Images are not saved or sent off-device.

Before review, upload the native-resolution screenshots produced by the `Caliqo App Store Screenshots` workflow and use a physical iPhone to test camera permission, AR distance, AR area, level, save/delete, share, VoiceOver, and Dynamic Type.
