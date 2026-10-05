# Lakwatsa Phase 1D — Firestore rules (review before deployment)

**Never paste or publish this rules file before emulator tests pass.** The existing
`lakwatsa_v2_users` rules are preserved, but the current `/users/{uid}` Activity
paths are now restricted.

## Changes to the Flutter app

The *only* required application change is in
`lib/repositories/firestore_activity_repository.dart`: use deterministic check
IDs `before_activity` and `return` instead of generating random IDs. Drafts
continue to use `draft_before_activity` and `draft_return`.

Existing completed check docs with random IDs **remain readable** as historical
records. Their identifiers are not rewritten or deleted.

## Run Firestore rules tests locally (without connecting to production)

Requirements: Node.js, npm, Java, an internet connection to install npm
packages, and the Firebase CLI (can be invoked through `npx firebase-tools`).

From the Flutter project's root in **PowerShell**:

```powershell
npm --prefix rules-tests install
npx firebase-tools emulators:exec --config firebase.phase1d.json --project demo-lakwatsa-phase1d --only firestore "npm --prefix rules-tests test"
```

`demo-lakwatsa-phase1d` is a **demo project ID**, not the real Firebase project.
The test runner loads rules from the local `firestore.rules` file. Do not
connect your Android app to the production database to run these negative tests.

If emulator startup complains about missing binaries, try:

```powershell
npx firebase-tools setup:emulators:firestore
```

The new emulator config uses a **separate** `firebase.phase1d.json` file; it
does not overwrite your FlutterFire `firebase.json`.

## Tests to run on Android *only after emulator tests pass and rules are deployed*

- Create Activity with initial Items, run Before Check and Return Check.
- Save and restore Before and Return drafts; try both manual and QR.
- Add a known Item to an ACTIVE Activity via QR.
- Verify completed History remains readable.
- Verify completed Activities cannot be edited or removed through client writes.

## What these rules do not guarantee

- The client still supplies check item rows. Rules limit which transitions may
  create rows, and block later mutations; they do **not** verify that every
  Activity Item has exactly one correctly reported check row. For high-assurance
  audits, use a trusted backend or a verifiable compact check manifest.
- Deleting Activity documents is intentionally **disabled**: the current
  `deleteActivity` implementation deletes only the parent and does not clean
  nested subcollections. A safe recursive delete would require a separate
  change.
- The original per-user Items and Lists remain owner-only (schema validation
  for those collections is a separate hardening task).
- There is no global catch-all allow. Paths not listed here remain denied.

## Development workflow

Do not commit or merge if the rule tests, `flutter analyze`, `flutter test`, or
Android regressions fail. Do not deploy to the production Firebase project
until the emulator results and the existing app's data shape are confirmed.
