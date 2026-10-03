# Firestore rules rollout

Project: `lakwatsa-bbriones-app`. Assessment date: 2026-10-03.

## Previous rules supplied by the user

The recursive match `/{document=**}` permits reads/writes before
`timestamp.date(2026, 10, 28)`. It does not require authentication. Leaving that
grant in place alongside restrictive rules does not secure the database:
Firestore grants a request if any matching allow condition is true.

Reference: https://firebase.google.com/docs/firestore/security/rules-structure#overlapping_match_statements

## Replacement prepared locally

`firestore.rules` restricts the reconstructed app to authenticated owners under
`lakwatsa_v2_users/{uid}`. It validates inventory and activity lifecycle writes,
prevents edits/deletion of completed activity history, and denies unmatched paths.
Owner-only compatibility rules also cover the supplied legacy layout:
`users/{uid}`, its items and lists (including list items), and activities with
their snapshot items and checks (including check items). User document IDs must
equal the corresponding Firebase Authentication UID, as used by the original
repository initialization in the supplied conversation. Compatibility rules do
not impose the rebuilt schema on older records or migrate any data.

The official local Firestore emulator tests cover:

- Owner inventory reads/writes and collection queries; cross-account and signed-out rejection.
- Anonymous creation and unknown collection rejection.
- List access/deletion restricted to the owner.
- Valid before/return transitions; skipped transitions, snapshot rewriting, saved
  before-result rewriting, and completed-history mutation/deletion rejected.
- Every supplied legacy document depth: owners retain access, other accounts and
  anonymous callers cannot read/write, and nested collection queries are isolated.

Latest verification: all five rules tests and all 30 tests in the complete enabled
suite pass. `flutter analyze --no-pub` reports no issues.

The user confirmed publishing this replacement on 2026-10-03. Publication and
live client access have not been independently verified by the agent.

## Publication and live verification

1. The user supplied the legacy `users/{userId}` tree; compatibility rules are now
   included. User IDs must match the Firebase Authentication UIDs used by the app.
2. Review `firestore.rules`. It preserves old write formats within the confirmed
   owner-scoped paths, and protects the new schema separately. It includes no
   public allow-all rule. No record migration is performed.
3. Copy the final complete rules file into Firebase Console > Firestore Database
   > Rules, replacing the entire public test-mode ruleset, and click Publish.
   Status: done according to the user's confirmation.
   Rules changes do not delete records, but can block clients whose paths have
   no matching allow rule.
4. Test the configured APK with two accounts: each can save/read its own items,
   lists, activity checks, and history, and cannot access the other's records.
5. Confirm Email/Password is enabled in Authentication and verify on a phone.

The replacement has no date-based expiry. Keep the deployed console rules and
repository file aligned. Do not restore the public test-mode rule as a rollback;
correct the specific denied path after identifying its ownership semantics.
