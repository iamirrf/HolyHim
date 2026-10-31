# Apple owner setup for HolyHer

Production app: `com.holyher.app`. Apple team: **Codellion LLC / DU9D6TAM58**. Google project: **holyher-app-production**, owner account **iamirrf1@gmail.com**.

## 1. Create the separate Sign in with Apple key

This is an Apple Developer key for authentication. The RevenueCat In-App Purchase key and App Store Connect API key cannot replace it. The installed and current upstream Spaceship key SDK do not implement Sign in with Apple key creation, so the helper does not invent a private Apple request.

In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list):

1. Select **Codellion LLC**. Open the App ID **com.holyher.app**. Enable **Sign in with Apple**, choose **Configure**, and classify HolyHer as the **primary App ID**. Save the configuration and the App ID page. Do not group it with Cognein. [Apple instructions](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)
2. Under **Identifiers**, select **Services IDs**. Reuse an existing HolyHer-only entry if it has the exact association below; otherwise register description **HolyHer Sign In**, identifier **com.holyher.app.signin**.
3. Open that Services ID, enable **Sign in with Apple**, and choose **Configure**. Select primary App ID **com.holyher.app**. Add domain **holyher-app-production.firebaseapp.com** and Return URL **https://holyher-app-production.firebaseapp.com/__/auth/handler**. Finish **Continue / Save** in the dialog and save the identifier page. The domain is a hostname without `https://`; the Return URL includes `https://`. [Apple website configuration](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web/), [Firebase configuration](https://firebase.google.com/docs/auth/ios/apple#configure_sign_in_with_apple)
4. Under **Keys**, check for an existing key named **HolyHer Apple Sign In** before creating another. Create that name, enable **Sign in with Apple**, choose **Configure**, and associate it only with primary App ID **com.holyher.app**. Register it, note its ten-character **Key ID**, and download its `.p8` file once. Keep the file outside both app repositories. Apple permits two keys per primary app; do not revoke any shared/Cognein key. [Apple key instructions](https://developer.apple.com/help/account/capabilities/create-a-sign-in-with-apple-private-key/)

Use the exact Services ID you registered if it differs from the suggested identifier. Do not paste the private key into chat or commit it.

## 2. Securely import the owner-downloaded key

Replace `ABCDEFGHIJ` below with the downloaded key's actual ID. Run from the HolyHer repository:

```sh
python3 tool/connect_apple_signin.py \
  --p8 "$HOME/Downloads/AuthKey_ABCDEFGHIJ.p8" \
  --key-id ABCDEFGHIJ \
  --service-id com.holyher.app.signin
```

The importer uses the existing Google CLI login for `iamirrf1@gmail.com`; it does not ask for an Apple password. It validates a P-256 private key and the production app/project, restricts the original key file to `0600`, and sends the key to a HolyHer-scoped Secret Manager version through stdin. It then configures Firebase's Apple provider using the official `appleSignInConfig.codeFlowConfig.teamId`, `keyId`, and `privateKey` fields, the separate Services ID, and native bundle allowlist `["com.holyher.app"]`. It verifies the backup and provider read-back in memory. It creates no additional local key copy and prints only public identifiers/status. Existing unrelated providers or differently labeled secrets are rejected. [Google provider schema](https://cloud.google.com/identity-platform/docs/reference/rest/v2/projects.defaultSupportedIdpConfigs), [stdin secret upload](https://cloud.google.com/sdk/gcloud/reference/secrets/versions/add)

Add `--dry-run` to validate the downloaded file without network access. Later, inspect non-secret provider configuration with:

```sh
python3 tool/connect_apple_signin.py --verify
```

Reimporting the same key reuses a matching Secret Manager version. Replacing an already configured key requires explicit `--replace-key`; only use this for an intentional rotation. The script retains the cloud backup if Firebase configuration fails. It never revokes Apple keys or grants additional Secret Manager IAM access.

The owner must still test **Apple sign-in → sign-out → reauthentication → account deletion** on a signed-in Apple device. Firebase requires the Services ID and OAuth code flow configuration for token revocation. [Firebase revocation requirements](https://firebase.google.com/docs/auth/ios/apple#token_revocation)

If Firebase authentication emails will be sent to Hide My Email addresses, register **noreply@holyher-app-production.firebaseapp.com** with Apple's private email relay service, or register the actual customized sender domain. [Firebase relay instructions](https://firebase.google.com/docs/auth/ios/apple#configure_sign_in_with_apple)

## 3. One private Terminal login for the App Store listing

Run this exact command directly in the owner's Terminal:

```sh
cd /Users/amir/Downloads/HolyHer
bash tool/apple_release_setup.sh --create-app --upload-metadata --upload-privacy --schedule-release
```

Enter the Apple ID, hidden password, and Apple's two-factor code when prompted. No password belongs in chat, a command argument, or a project file. The helper creates missing HolyHer records, uploads the prepared metadata/screenshots and review narrative, saves the privacy answers as an **unpublished draft**, and reads back the scheduled release policy. The notes-only review upload preserves existing reviewer contact, demo credentials/requirement, and attachments; it never fills these private details with blanks or logs their values. Enter real reviewer contact/credentials securely in App Store Connect. The helper sets automatic release **after approval, no earlier than November 15, 2026 at 06:00 EST / 11:00 UTC**. It does not submit App Review or upload a build.

The authenticated cookie is kept in `~/Library/Application Support/HolyHer/apple-release/spaceship/<Apple ID>/cookie`, under private directories and file permissions. Subsequent work on this Mac can reuse it without another password:

```sh
bash tool/apple_release_setup.sh --reuse-session --inspect
```

The same `--reuse-session` flag works with `--upload-metadata`, `--upload-privacy`, `--publish-privacy`, or `--schedule-release`. Reuse validates the saved account and exact team, intercepts the SDK adapters' repeated login calls, and disables credential/Keychain login paths. Missing, malformed, or expired sessions stop without prompting or falling back. Apple controls expiry; fastlane documents a variable lifespan of roughly one day to one month, so another owner Terminal login may eventually be necessary. [Fastlane session documentation](https://docs.fastlane.tools/getting-started/ios/authentication/)

Publish the privacy draft only after checking the final archive's actual SDK/data behavior. App Review contact, demo access, required questionnaires, real-device purchase/restore/account-deletion acceptance, and the signed upload remain release gates.

## 4. Inspect remaining Apple gates using the saved session

The agent can inspect the remaining Apple setup without requesting another owner password while the saved session remains valid:

```sh
bash tool/apple_release_setup.sh --reuse-session --inspect-release-gates
```

This makes read-only API requests for app download prices/availability, the current age declaration, content rights, reviewer-detail completeness, uploaded builds/encryption declarations, the lifetime product/review screenshot, and its association with a matching review submission. Reviewer contact and demo credentials appear only as presence booleans; their values are never printed or written. The sanitized report is saved privately as `apple-release/release-gates.json`. It does not set prices, answer questions, upload builds, or submit anything. Unknown/unavailable fields stay unknown. A missing review-submission association does not prove an unsent portal selection is absent, and Apple may redact a saved demo password.

Newer fields use the installed SDK's authenticated GET transport and raw JSON, checked against Apple's **OpenAPI 4.5.1** specification, SHA-256 **7b826ae9ca3e45b0e7df2643cbb811c9930632640944db11a8af4586fab9db46**. [Official specification download](https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip)

The installed Deliver supports the documented `price_tier: 0` option and legacy app-territory updates, but these have not been verified against the live current app. A free app download is separate from the verified US$1.99 lifetime IAP. Current official APIs provide app price schedules and v2 availability. The older SDK's age model omits newer questionnaire fields such as age assurance, parental controls, messaging/chat, health/wellness, weapons, social media, and advertising. The inspector reads those current fields; no legacy template is treated as a complete questionnaire, and no answers are guessed. [Apple age-rating setup](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
