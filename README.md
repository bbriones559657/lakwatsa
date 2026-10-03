# Lakwatsa

Android belongings tracker: authenticated inventory, reusable packing lists,
activity snapshots, manual/QR before and return checks, saved history, and local
return reminders. This is a reconstruction from the available prototype and
conversation, not a recovery of the unavailable device's source code.

## Setup

1. Install Flutter/Dart and Android build tools. This checkout was developed with
   Flutter 3.47.6 / Dart 3.13.5. On Windows, enable Developer Mode for plugin links.
2. In Firebase project `lakwatsa-bbriones-app`, enable Email/Password in
   Authentication and create the default Cloud Firestore database if absent.
3. In Project settings > General > Your apps, select the registered Android app.
   Its package name must match the applicationId in `android/app/build.gradle.kts`:
   `com.bbriones.lakwatsa.rebuilt`. Register this as another Android app in the
   same Firebase project; keep the original `com.bbriones.lakwatsa` registration.
   The launcher label is Lakwatsa Rebuilt so both installations are distinguishable.
   The Kotlin namespace remains `com.bbriones.lakwatsa`; the manifest explicitly
   names its MainActivity. The new Firebase client configuration was supplied
   and the separate APK installed on the Samsung phone on 2026-10-03.
4. Create `firebase-config.local.json` using `firebase-config.example.json` and
   values from the registered app's `google-services.json`: `current_key` is
   `FIREBASE_API_KEY`, `mobilesdk_app_id` is `FIREBASE_APP_ID`, and `project_number`
   is `FIREBASE_MESSAGING_SENDER_ID`. If the download contains multiple clients,
   select the one with package name `com.bbriones.lakwatsa.rebuilt`.
   These are client configuration values;
   never use a service-account key in the app. The local file is gitignored.
5. The previously supplied production rules used a public test-mode wildcard until
   2026-10-28. Replace that ruleset rather than retaining the public wildcard:
   overlapping allow statements would bypass the new restrictions. The local
   `firestore.rules` covers `lakwatsa_v2_users` and the user-supplied legacy
   `users/{uid}` layout, including nested list/activity/check items. Both require
   the user document ID to equal the signed-in Firebase UID. Legacy rules preserve
   existing write formats; stricter lifecycle validation applies to the rebuilt
   schema. Unknown paths are denied. No production rules were changed by the
   agent. The user confirmed publishing the replacement on 2026-10-03; live access
   is not independently verified. See `docs/FIRESTORE_ROLLOUT.md` for rollout checks.
6. Run `flutter pub get`, then:

   ```powershell
   flutter run --dart-define-from-file=firebase-config.local.json
   flutter build apk --debug --dart-define-from-file=firebase-config.local.json
   ```

   In VS Code, select **Lakwatsa (Firebase Android)** from Run and Debug; the
   included launch configuration passes this same local Firebase config file.

No Firebase configuration or rules have been deployed automatically. A build
without the local configuration can compile but displays a configuration error;
it is not a usable connected deliverable. Android is the delivery target.
Other generated platform folders do not imply verified support.

## Source layout

- `lib/main.dart`: initialization and authentication routing.
- `lib/firebase_config.dart`: Firebase client configuration.
- `lib/domain/`: validated data models, QR payload rules, reminder timing.
- `lib/repositories/packing_repository.dart`: user-scoped Firestore persistence
  and transactional activity lifecycle.
- `lib/services/reminder_service.dart`: Android permission, scheduling,
  reconciliation, cancellation, and notification payloads.
- `lib/app/`: app shell, authentication, individual item/list/activity editors,
  activity checks/history, QR display, and camera scanner.
- `lib/app/views/`: separate live-data Home, grouped Items, Lists grid, and
  Activities views, adapted from the original app inspected on the phone.
- `lib/app/widgets/retro_widgets.dart`: shared outlined/shadowed panels, pixel
  badges, category icons, search field, progress bar, and text navigation.
- `lib/app/list_details_screen.dart`: live list membership with edit navigation.
- `lib/theme/`: shared colors and typography from the original design.
- `lib/screens/`, `lib/models/item.dart`, `lib/data/mock_items.dart`: original
  prototype retained for reference; the new app entrypoint does not use them.
- `test/`: domain, repository, authentication UI, startup, and emulator rules tests.

## Data and behavior

The reconstructed schema is isolated at
`lakwatsa_v2_users/{uid}/{items|lists|activities}/{id}`. This prevents writes over
unknown older schemas. Existing records and QR labels from the older app are not
automatically migrated or accepted. Assess migration when that source is available.

Inventory is archived/restored instead of permanently deleted, preserving list
references. Lists hold unique item IDs and per-list quantities. Activities copy
item names, categories, and quantities; subsequent inventory/list edits do not
rewrite the snapshot. Limit: 200 distinct item types per list/activity; quantity
1-999. Lists may be empty, but activities must have at least one item.

Each check is binary for the item's full displayed quantity. Checking one item
with quantity 3 confirms all 3 pieces. Partial-quantity counting is not implemented.
Progress is saved before leaving the check screen. Activity changes require an
internet connection because transactions protect against stale confirmations and
double completion. Cached Firestore reads may be available offline; initial
authentication and confirmed saves still require connectivity.

The flow is planned -> before check -> active -> return check -> completed.
Open activities can be cancelled or have their end time changed. Final check
results are read-only. Each result retains its own item set, so a QR addition
during the return check does not change the before-check denominator.

QR codes use `lakwatsa://item/{uid}/{itemId}`. A QR from another account or unknown
format is rejected. A known owned item can be added only to the current activity;
the reusable list is unchanged. QR images can be captured/printed from the item
screen; file export and photo attachments are not part of this reconstruction.

Reminders use the device timezone and Android inexact alarms. They start when an
activity becomes active; late starts use the end time. Delivery can be delayed by
Android power management. Cancellation/completion/sign-out clears relevant pending
alarms. Remote changes reconcile when this device receives them or resumes; an
offline/terminated device cannot learn a remote cancellation instantly. This is a
local notification system, not a push service. Force-stop reconciliation and
completion cancellation were verified on the connected Samsung. Permission
denial, reboot, timezone changes, actual delivery, and notification-tap navigation
still need physical-device verification.

## Verification

Visual and workflow check (2026-10-03): 25 local tests pass and five official
Firestore-emulator rules tests pass; the analyzer is clean and the configured
Android APK builds. On the Samsung, sign-up/sign-in/item creation, list creation,
the complete manual before/return activity flow, persisted drafts across forced
restarts, immutable completed history, camera permission/scanner startup, physical
owned-item QR decoding with saved QR provenance, and alarm registration/
reconciliation/completion cleanup were verified. No Flutter or Android runtime
errors were logged during the final history check. Notification delivery/tap and
live two-account isolation remain open; live invalid/foreign QR cases are covered
only by automated tests.

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Repository tests use FakeFirebaseFirestore. Its dummy transactions do not emulate
server conflict retries/rollback; `test/support/settled_firestore.dart` drains its
asynchronous writes for deterministic sequential checks. This does not replace
backend integration or real-device tests.

Rules tests require the official Firestore emulator. They are explicitly skipped
in the default suite. With Java 21 and the downloaded official emulator:

```powershell
java -jar .tools/cloud-firestore-emulator-v1.22.0.jar --host 127.0.0.1 --port 8080 --project_id demo-lakwatsa-rules --rules firestore.rules
flutter test --no-pub --dart-define=FIRESTORE_RULES_TEST=true test/firestore_rules_test.dart
```

These tests target localhost with a demo project and never use production data.

## Completion checklist

See `DEVELOPMENT_PLAN.md` for the assessment and ordered todo. Before calling the
project complete: verify live owner isolation, camera-permission denial/recovery,
invalid/foreign QR behavior, and notification delivery/tap navigation. Firebase
connection, Android installation, valid QR camera decoding, both checks, restart
persistence, and saved history now pass. Store publishing also needs a deliberate
package ID, release signing key, and distribution setup; the template release build
uses debug signing.
