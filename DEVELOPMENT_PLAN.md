# Lakwatsa recovery plan

Assessment date: 2026-10-03 (Asia/Singapore).

## Implementation and verification update

The missing app has now been reconstructed in separate domain, repository,
service, authentication, editor, activity/history, and QR screen files. The new
entrypoint uses this implementation; the original prototype screens remain as
reference. Backend records use `lakwatsa_v2_users/{uid}` to avoid overwriting the
unavailable version's unknown schema. The agent has not changed production data.
The user confirmed publishing the replacement rules on 2026-10-03 and subsequently
reported successful sign-up, sign-in, and item creation. A real-device list and
complete manual activity lifecycle have also been verified. A second activity
verified physical QR decoding and saved QR provenance. Live cross-account access
control and notification delivery/tap behavior are not yet verified.

### Live Android workflow verification (2026-10-03)

On the connected Samsung, the rebuilt app created `Final Test List` from the
persisted `Passport` item and created `Final Test Activity` from that list. The
planned before-check draft survived a force-stop and cold restart. Confirming the
1/1 manual before check moved the activity to active; the 1/1 return-check draft
also survived a force-stop and cold restart. Completing the activity produced
read-only history with separate before and return timestamps and MANUAL provenance.
That completed history remained intact after another cold restart.

Android registered the expected return alarm for 30 minutes before the activity
end, restored/reconciled it after restart, and removed the pending alarm when the
activity completed. Camera permission was granted and the live scanner opened
without Flutter or Android runtime errors. A real Passport QR displayed on the
computer was decoded through the phone camera in `QR Test Activity`; immutable
history records `BEFORE FOUND · QR` and `RETURN FOUND · MANUAL`. Notification
delivery/tap remains unverified.

### Original visual style restoration (2026-10-03)

Inspected the original installed app's Home, Items, Lists, and Activities screens.
Restored its black outlines, offset shadows, pixel labels, cream/green/orange
palette, text navigation, grouped inventory, list grid/Edit mode, and
Upcoming/Active/History controls. Separate stateless views live in `lib/app/views`,
with reusable visuals in `lib/app/widgets/retro_widgets.dart` and a separate
live list-details screen. The shell retains authentication, streams, reminders,
and navigation. No database schema or rules changes were needed.

Dashboard values use real records: no fake Beach Trip, packing totals, list
statuses, or fixed 9:41 clock. Original photo/icon customization and QR export
are not implemented by this visual update; existing README limitations remain.

Verification: 25 non-emulator tests pass, including six new UI tests; five
emulator-only tests are skipped by the default command (previous rules run
passed). Analyzer is clean. The configured APK builds and was updated on the
Samsung without uninstalling either app. Phone inspection confirms the restored
layouts, persisted item/list data, the manual before/return workflow, completed
history, restart recovery, and physical QR decoding with saved provenance.
Delivered-notification navigation remains open.

### Side-by-side installation update

The Samsung SM G973W is connected. Updating its existing installation failed with
INSTALL_FAILED_UPDATE_INCOMPATIBLE because the signing keys differ. No app was
uninstalled and no local data was cleared. The user approved a separate install.
The rebuilt application ID is now `com.bbriones.lakwatsa.rebuilt`, with launcher
label Lakwatsa Rebuilt. Its new Firebase Android configuration was verified from
the user's downloaded google-services.json and applied to the gitignored local
config. The separate APK built successfully, was inspected for the correct
package/label/activity, installed, and launched on the Samsung on 2026-10-03.
ADB confirms both packages remain installed. The user reports actual sign-up,
sign-in, and item creation work. Manual activity operations and alarm registration/
cancellation and physical QR decoding are now live-verified. Cross-account
isolation and notification delivery/tap still require live validation.

Verified locally:

- [x] Domain validation, QR account checks, immutable snapshots, check totals.
- [x] Repository lifecycle, saved draft restoration, unchecking, rescheduling,
      activity-only QR additions, and stale-confirmation rejection in test storage.
- [x] Authentication form validation and a narrow phone layout; startup errors.
- [x] Reminder timing including expired, completed, resumed, late-start, and
      rescheduled activities.
- [x] Official Firestore emulator: actual rules compile, owner reads/writes and
      queries work, other/anonymous users are denied, lifecycle writes succeed,
      and completed history cannot be changed/deleted.
- [x] Full enabled suite: 30 tests pass (25 local plus five official emulator
      rules tests). Command:
      `flutter test --no-pub --dart-define=FIRESTORE_RULES_TEST=true` with emulator.
- [x] Registered Firebase client configuration supplied and verified against
      `lakwatsa-bbriones-app` for application ID `com.bbriones.lakwatsa.rebuilt`.
      Namespace and explicit MainActivity remain `com.bbriones.lakwatsa`.
- [x] Firebase client values saved to gitignored `firebase-config.local.json`;
      VS Code launch configuration supplies it automatically.
- [x] CONFIGURED Android debug APK builds successfully with the registered app
      values. The user verified sign-up, sign-in, and a live item write/read.
- [x] Final `flutter analyze --no-pub`: no issues found.

Remaining delivery gates, in order:

1. Confirm Email/Password authentication and the default Firestore database.
   The user confirmed replacing the public rules on 2026-10-03. The supplied
   legacy users/{userId} tree has owner-only compatibility rules for all listed
   subcollections. Verify the live rules with two real accounts.
   Latest replacement-rules run: five official emulator tests pass, including
   legacy nested paths, anonymous/cross-user writes, unknown paths, list deletion,
   and history integrity. The full 30-test enabled suite and analyzer also pass.
   Rollout notes: `docs/FIRESTORE_ROLLOUT.md`.
2. Separate configured app built, installed, and launched on the Samsung (done).
   The old installation remains present; no uninstall or data clearing was used.
3. Completed live: sign-up/sign-in/item write, list creation, activity creation,
   persisted manual before/return drafts, completion, immutable history after a
   cold restart, camera permission/scanner startup, and reminder registration,
   restart reconciliation, and completion cleanup. Still exercise password reset,
   QR decoding passes for a valid owned item; still exercise live invalid,
   duplicate, and other-owner codes, permission denial/re-enable, reminder
   delivery, reboot, notification taps, cancellation, and sign-out cleanup.
4. Review deliverable requirements against limitations in README: Android target,
   archive/restore inventory, whole-quantity binary checks, no photo attachment or
   QR file export, no migration of old records/QR labels, and debug signing until
   a release signing identity is supplied. Do not silently treat these as accepted
   if the user's submission requires them.

The project is NOT marked complete until the remaining gates pass.

## Evidence and scope

This checkout is an earlier Flutter UI prototype. The user's transcript reports
working Firebase, activities, QR checks, and history on an unavailable device;
those implementations are not present here and cannot be marked verified.

Confirmed: Save Item only navigates back; Lists and Activities tabs are
placeholders; list membership is temporary sample data; the widget test is
commented out. Existing themes, forms, and item selection provide reusable UI.
Baseline `flutter analyze --no-pub`: two unused-import warnings, no errors.

Target: a complete Android app with authenticated, user-scoped Firebase data,
items, reusable lists, activity snapshots, manual/QR before and return checks,
immutable completed history, and local return reminders. Preserve the existing
visual direction. Firebase project configuration and real-device validation are
required completion gates, not optional demo substitutions.

## Ordered todo and acceptance criteria

- [ ] Confirm Firebase project and Android registration; configure authentication
      and Firestore with owner-only access rules; verify two-account isolation.
- [x] Implement validated models and injectable repositories for items, lists,
      activities, check results, and resumable check drafts.
- [x] Connect item create/edit/archive/search and real QR generation to saved data.
      Restart and sign back in: saved items must remain.
- [x] Connect reusable lists and membership; enforce positive quantities and
      unique item membership. Removing membership must not delete the item.
- [x] Create activities from list snapshots; later list edits must not change
      existing activities. Enforce planned -> active -> completed transitions.
- [x] Implement resumable before/return checks with MANUAL and QR provenance,
      missing-item confirmation, duplicate scan handling, invalid-code feedback,
      and activity-only additions of other owned items.
- [x] Display completed check history with correct per-check totals and clear
      treatment of items added after the before check.
- [x] Schedule timezone-aware reminders; handle permission denial, completion,
      cancellation, sign-out, rescheduling, and notification navigation.
- [x] Replace mock dashboard values with saved data; provide loading, empty,
      error, retry, and busy states for all user-facing operations.
- [x] Run model/repository/widget tests and analyzer; test Firebase rules.
- [ ] Build and install Android artifact (build/install done); finish denied-
      permission, connectivity-loss, and delivered-notification behavior on a
      phone. Restart persistence, camera startup, and owned-item QR decoding pass.
- [x] Document setup, supported platform, verification evidence, and unresolved
      limitations. A successful build alone is not proof of feature completion.

## Delivery constraints

Firebase client configuration and the user-supplied current rules are available;
The legacy data layout is confirmed and covered by tested owner-only rules;
authenticated Firebase administration access is not available to the agent.
The Samsung phone is connected and the configured side-by-side app is installed.
The core manual journey is live-verified; external-account and timed-delivery
tests remain. Do not claim completion while any required gate remains unverified.
Defer cosmetic redesign and extra features until the requested user journey is
implemented and tested.
