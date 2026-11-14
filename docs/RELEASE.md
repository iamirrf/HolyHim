# HolyHim 1.0 release runbook

App **HolyHim: Daily Bible for Men**, bundle `com.holyhim.app` (widget `com.holyhim.app.widget`,
App Group `group.com.holyhim.app`), team Codellion LLC (`DU9D6TAM58`), version 1.0.0 (1).
Cloud: `holyhim-app-production` (owner `iamirrf1@gmail.com`). Purchases: RevenueCat project
`proj1b08bf4e`, non-consumable `holyhim_lifetime` at $1.99, entitlement `lifetime`. Days 1 to 7 free.

## Done (Nov 13 to 14)

| Step | How |
|---|---|
| Cloud project, Firestore, Storage, runtime account, iOS and web apps | `tool/bootstrap_cloud.py` |
| Sign-in: email, Apple (native), Google | bootstrap + Firebase console |
| Firestore and Storage rules, thirteen functions (six core, seven community), website | `tool/deploy_rules.py --deploy`, `node tool/deploy_with_gcloud.cjs storage`, `DEPLOY_FORCE=1 node tool/deploy_with_gcloud.cjs functions:holyhim` (each item in a list needs its own `functions:` prefix; new callables need `allUsers` as Cloud Run invoker), `node tool/deploy_with_gcloud.cjs hosting` |
| RevenueCat project, app, product, entitlement, offering, webhook | `tool/setup_revenuecat.py --webhook` |
| All lessons, 73 chapters, all validators | `tool/him_batch.py`, see README |
| Redesign: glass bars, walk road, Brothers community and board, 3D medallions, restored profile | `lib/features/{shell,walk,community,growth,profile}` |
| Listing text, review notes (with the community section), eight screenshots | `store/metadata/`, `store/screenshots/app-store/iphone-1290x2796/` |

Website: https://holyhim-app-production.web.app (privacy, terms, support).

## Owner steps (your own Terminal; each asks for secrets privately)

```sh
cd /Users/amir/Downloads/HolyHim
```

1. **App Store record + saved Apple session** (Apple ID, password, 2FA). Creates the bundle ID and
   the app record, then uploads the listing, screenshots, review notes and privacy answers:

   ```sh
   bash tool/apple_release_setup.sh --create-app --upload-metadata --upload-privacy
   ```

2. **RevenueCat ↔ App Store** (Apple 2FA). Creates the In-App Purchase key and App Store Connect
   key inside RevenueCat so purchases validate and the product can be created from RevenueCat:

   ```sh
   bash tool/connect_apple.sh
   ```

3. **RevenueCat server key.** In RevenueCat, project **HolyHim** → API keys → New secret API key (v2)
   with *Customer information: Read & write* and *Project configuration: Read*, then paste it at the
   hidden prompt:

   ```sh
   python3 tool/connect_revenuecat_backend.py
   ```

4. **Sign in with Apple key** (recommended; deletion works without it, but revocation needs it):
   `store/APPLE_OWNER_SETUP.md` sections 1 and 2, for `com.holyhim.app`.

5. **App Review contact** in App Store Connect → App Review Information: name, phone, email.

6. **iPhone checkpoint** (unlocked, same Wi-Fi), about ten minutes:
   `python3 tool/run_iphone.py --mode release`, then Apple, Google and email sign-in, allow
   notifications, one sandbox purchase and Restore.

## After the owner steps (agent)

- Create the purchase in App Store Connect from RevenueCat (`rc products store sync` / `push`),
  upload its review screenshot (`build/render/store/iap-offer.png`).
- Redeploy the two billing functions so they read the new server key:
  `DEPLOY_FORCE=1 node tool/deploy_with_gcloud.cjs functions:holyhim:syncAccess,functions:holyhim:revenuecatWebhook`.
- Build, verify and upload:

  ```sh
  flutter build ipa --release --obfuscate --split-debug-info=build/symbols/1.0.0+1 --export-method app-store
  python3 tool/verify_archive.py build/ios/archive/Runner.xcarchive
  python3 tool/release_gate.py
  bash tool/apple_release_setup.sh --reuse-session --upload-archive build/ios/archive/Runner.xcarchive
  ```

- Attach build and purchase to version 1.0.0, release automatically after approval, submit.

Keep `build/symbols/1.0.0+1/` until the next release: it is needed to read obfuscated crashes.

## Every day after launch: community reports

Apple holds us to the promise in the Terms: reports reviewed within 24 hours.

```sh
python3 tool/moderation.py list                  # open reports with the text
python3 tool/moderation.py remove POST_ID        # or: --reply REPLY_ID
python3 tool/moderation.py ban UID               # card removed, posts hidden, no rejoining
python3 tool/moderation.py close REPORT_ID
```

Posts reported three times hide themselves until reviewed; `restore` brings
one back if the reports were wrong.
