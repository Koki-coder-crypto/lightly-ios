# Global launch checklist

## Ready in the release

- English (U.S.) App Store names, descriptions, keywords, and review notes are in `GLOBAL_STORE_LISTINGS.md`.
- The shared privacy and support pages are available in English at the live GitHub Pages URLs used by all five apps.
- The primary English UI and subscription disclosures are localized with `en.lproj` resources.
- Builds use App Store distribution signing and are uploaded to TestFlight.
- All apps are designed for device-local storage; no account, analytics, ads, or server-side user data are used.

## Set in App Store Connect after paid agreement activation

- Add the English (U.S.) localization from `GLOBAL_STORE_LISTINGS.md` to each app and each subscription product.
- Select worldwide availability, excluding the EU until the account holder completes the DSA trader-status flow.
- Complete privacy nutrition labels: no data collected; declare only required device permissions per app.
- Upload localized 6.7-inch iPhone screenshots and select the processed TestFlight build.
- Submit each version and its first subscription group for App Review.
