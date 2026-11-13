# HolyHim v2 backend

The deployment exports two endpoints: `deleteAccount` and `supportRequest`. All walk, saved verse and preference writes go directly to the owner's Firestore documents. There are no completion, journey, billing or checkpoint callables.

`deleteAccount` requires Firebase authentication from the last five minutes. It writes the permanent `deletionGuards/{uid}` document, recursively deletes `users/{uid}`, and deletes the Firebase Auth identity. Apple token revocation happens in the client before this call. A failed deletion can be retried; the guard continues rejecting delayed device writes.

`supportRequest` retains the website/app support payload, honeypot, three-per-IP/hour rate limit and Firestore support inbox. Hosting routes `/api/support` to this endpoint.

## Verification

Run `node --test functions/test` from the repository root for isolated handler tests. Rules tests skip when no emulator is running.

Run the complete local suite with a demo project:

```sh
firebase emulators:exec --project demo-holyhim --config firebase.emulators.json --only firestore 'node --test functions/test'
```

The emulator requires Java 21 or newer. The test client refuses a production project or a non-local emulator address. Tests cover the actual profile, progress and saved payload shapes, merge masks, all 365 day keys, removed fields, invalid member types and the account deletion guard.

## Saved verse migration

Firestore Rules cannot iterate arbitrary maps and impose a 1,000-expression limit. The rules validate a complete completion map with a date expression and a separator-count/length check. They validate changed saved timestamps through a binary choice of fixed 20-day blocks. A normal bookmark mutation affects one day; migration groups saved keys by `floor((day - 1) / 20)` and writes each group separately. This keeps validation bounded even when the saved document contains all 365 verses.

The legacy `private/journey` and `private/savedCatalog` documents remain readable by their owner for client migration. They are never client writable. All other retired collections are denied.

Production deployment and removal of old deployed functions require the release owner's explicit go-ahead. No deployment occurs during development or testing.
