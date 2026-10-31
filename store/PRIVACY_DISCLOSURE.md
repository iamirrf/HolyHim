# HolyHer privacy disclosure preparation

Prepared October 29, 2026 from the app/backend source, downloaded iOS SDK manifests, and primary provider documentation. These are recommended App Store Connect answers awaiting final archive verification and entry in the portal. They are not evidence that a privacy label has been submitted.

HolyHer has no advertising, advertising attribution integration, Firebase Analytics, or Crashlytics package. Nevertheless, its service providers declare technical or purchase analytics. Do not select “Data Not Collected” or claim that no analytics of any kind occur.

## Recommended disclosure baseline

All listed categories are **not used for tracking** under the currently inspected implementation. “Linked” means connected to an account or identity, including a Firebase UID or sign-in provider identity.

| Apple data type | Linked | Purposes | Evidence in this release |
|---|---|---|---|
| Name | Yes | App Functionality; Product Personalization | Provider-supplied/display name, saved preferred name, greeting. |
| Email Address | Yes | App Functionality | Email and federated authentication; password reset; support replies. |
| Phone Number | Yes | App Functionality | Google Sign-In SDK declares this category. HolyHer has no phone-auth UI; retain the vendor-declared baseline unless provider-specific evidence justifies narrowing. |
| Coarse Location | Yes | App Functionality | Google Sign-In SDK declaration. HolyHer requests no GPS permission; that does not negate provider collection. |
| Sensitive Info | Yes | App Functionality; Product Personalization | Saved Bible familiarity and faith-oriented focus can disclose religious information. |
| User ID | Yes | App Functionality; Analytics | Firebase UID, authentication provider identifiers, and the same UID used in RevenueCat's purchase reporting. |
| Device ID | Yes | Analytics | Google Sign-In SDK declaration. No advertising-identifier integration was found in HolyHer. |
| Purchase History | Yes | App Functionality; Analytics | RevenueCat entitlement/restore validation and purchase dashboard features; linked by the custom UID. |
| Product Interaction | Yes | App Functionality | Completed lesson numbers, activity dates, journey start and synced reading state. |
| Other Usage Data | Yes | Analytics | Google Sign-In SDK declaration. |
| Customer Support | Yes | App Functionality | The support website stores the submitted email and message. Include this accessible support surface in the baseline. |
| Other Data Types | Yes | App Functionality; Product Personalization; Analytics | Saved routine/reminder preferences and journey time zone; backend invocation/security metadata; Google Sign-In's additional data declaration. |
| Other Diagnostic Data | No | Analytics | FirebaseAuth and FirebaseFirestore SDK manifests declare unlinked technical diagnostics. |

Do not add payment-card information simply because the app uses StoreKit: Apple handles payment and HolyHer does not receive card details. No app code requests contacts, photos, microphone, health, or precise location. Recheck the final dependency set and actual provider behavior before using these exclusions as portal answers.

Google Sign-In's downloaded manifest declares linked Name, Email Address, Phone Number, Coarse Location, User ID, Device ID, Other Usage Data, and Other Data Types. The baseline above intentionally retains that declaration. Do not remove categories solely because the Dart layer does not read them. If narrowing is justified, record the provider documentation/configuration and runtime evidence before changing the label.

RevenueCat's SDK manifest alone describes an unlinked purchase record for basic operation. HolyHer supplies an account-identifiable UID, and RevenueCat's official disclosure guide additionally requires purchase Analytics and App Functionality. The app-level declaration therefore correctly treats its purchase history as linked and includes both purposes.

## App manifest and archived SDKs

`ios/Runner/PrivacyInfo.xcprivacy` declares HolyHer's direct collection and app-local UserDefaults use with approved reason **CA92.1**. SharedPreferences caches account-specific preferences and journey state within the app container. The SDKs' own manifests retain their separate API reasons and data declarations; do not copy wrapper-only reasons into the app manifest.

The app manifest must be included in the Runner resources. This task does not edit the Xcode project. Generate and inspect Xcode's combined privacy report from the actual distribution archive before submission, including Flutter, Firebase, Google Sign-In, RevenueCat, and all transitive resources. Downloaded source manifests and their hashes are inventoried in `metadata/sdk_privacy_audit.json`; a source inventory does not prove the archive contains them.

## Data flow and retention details

- Firebase Authentication handles Apple/Google/email sign-in. Firestore stores account setup, journey start/time zone, completed days, and activity dates. Cloud Functions receives authenticated requests and ordinary invocation metadata, including caller IP as documented by Firebase.
- Reminder delivery is local. The account stores a preferred reminder time; the app does not request an APNs token through Firebase Messaging.
- The website support endpoint stores email/message. A rotating one-way request-address identifier rate-limits submissions and is scheduled for deletion after 24 hours. Do not describe hashing as a guarantee of anonymization.
- In-app account deletion removes account/profile/journey data and requests RevenueCat customer deletion. A server-private one-way account marker blocks delayed billing reconciliation from recreating deleted records; Apple retains its own transaction records. Verify the deployed deletion path and disclose actual exceptions accurately.
- Support records are retained for handling requests and applicable obligations. Confirm and document the operational retention/deletion practice before promising a fixed support retention period.

## Final checks still required

Confirm the exact archive dependency versions and combined privacy report, save App Privacy answers in App Store Connect, verify the public privacy policy and support form, and ensure provider/operations practices match the published text. The configured Hosting routes returned HTTP 404 during this audit. Real production behavior and a final archive can reveal additional disclosures beyond this source review.

Primary references: [Apple privacy categories and disclosure rules](https://developer.apple.com/app-store/app-privacy-details/), [Apple approved API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons), [Firebase Apple data disclosure](https://firebase.google.com/docs/ios/app-store-data-collection), [RevenueCat Apple privacy guidance](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy), [Google Sign-In's own manifest](https://github.com/google/GoogleSignIn-iOS/blob/main/GoogleSignIn/Sources/Resources/PrivacyInfo.xcprivacy).
