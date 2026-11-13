# HolyHim 1.0 release runbook

App: **HolyHim**, bundle `com.holyhim.app`, team Codellion LLC (`DU9D6TAM58`).
Cloud: Google/Firebase project `holyhim-app-production` (owner `iamirrf1@gmail.com`).
Purchases: RevenueCat project `proj1b08bf4e`, product `holyhim_lifetime` ($1.99, non-consumable),
entitlement `lifetime`. Days 1 to 7 are free.

## Done

| Step | How | Status |
|---|---|---|
| Cloud project, Firestore, Storage, runtime account, iOS and web apps | `tool/bootstrap_cloud.py` | Done Nov 13 |
| Sign-in providers: email, Apple (native), Google | bootstrap + Firebase console | Done Nov 13 |
| Firestore and Storage rules | `tool/deploy_rules.py --deploy`, `node tool/deploy_with_gcloud.cjs storage` | Deployed Nov 13 |
| Six functions | `DEPLOY_FORCE=1 node tool/deploy_with_gcloud.cjs functions:holyhim` | Deployed Nov 13 |
| RevenueCat project, app, product, entitlement, offering, webhook | `tool/setup_revenuecat.py --webhook` | Done Nov 13 |

## Owner steps (run in your own Terminal; each asks for secrets privately)

1. **Create the App Store record and save an Apple session** (Apple ID, password, 2FA):

   ```sh
   cd /Users/amir/Downloads/HolyHim && bash tool/apple_release_setup.sh --create-app
   ```

2. **Connect RevenueCat to the App Store** (creates the In-App Purchase key; Apple 2FA):

   ```sh
   cd /Users/amir/Downloads/HolyHim && bash tool/connect_apple.sh
   ```

3. **Store RevenueCat's server key** (purchases unlock only after the server confirms them).
   In RevenueCat, open project **HolyHim** → *API keys* → *New secret API key* (v2), with
   *Customer information: Read & write* and *Project configuration: Read*. Then:

   ```sh
   cd /Users/amir/Downloads/HolyHim && python3 tool/connect_revenuecat_backend.py
   ```

   Paste the key at the hidden prompt. Afterwards the two billing functions are redeployed
   (`DEPLOY_FORCE=1 node tool/deploy_with_gcloud.cjs functions:holyhim:syncAccess,holyhim:revenuecatWebhook`).

4. **Sign in with Apple key** (lets account deletion revoke Apple tokens). Follow
   `store/APPLE_OWNER_SETUP.md` section 1 for `com.holyhim.app`, then section 2.

5. **iPhone checkpoint**: unlocked, awake, on this Wi-Fi. About ten minutes: Apple sign-in,
   Google sign-in, allow notifications, one sandbox purchase and restore.

6. **App Review contact**: a name, phone number and email for Apple's review form.

## Release

```sh
flutter build ipa --release --obfuscate --split-debug-info=build/symbols
python3 tool/verify_archive.py build/ios/archive/Runner.xcarchive
python3 tool/release_gate.py
bash tool/apple_release_setup.sh --reuse-session --upload-archive build/ios/archive/Runner.xcarchive
```

Then attach the build, the $1.99 purchase and its review screenshot to version 1.0.0 and submit
with automatic release on approval.
