# Lakwatsa v3 — emergency reconstruction

This branch restores the **core user journey** from the latest Lakwatsa work. It is a new reconstruction, not an exact copy of the inaccessible laptop. Original Figma-inspired palette, Plus Jakarta Sans typography and outlined cards are retained. Some layouts are still simplified.

**Features coded:** Firebase email/password authentication; user-scoped Firestore Items; permanent optional Item QR; reusable Lists, membership and deletion protection; Activity snapshots and Upcoming/Active/History workflow; manual or QR Before/Return checks; unknown/duplicate QR handling; adding a known QR Item to the current Activity; saved FOUND/NOT_FOUND and MANUAL/QR methods; Check Results.

**Not yet implemented:** actual scheduled notifications, Item photo uploads. Reminder preference is stored but does NOT schedule alerts. Do not represent either unfinished feature as complete.

## Setup on your new Windows laptop

1. Make sure Flutter, Android SDK, Chrome and VS Code are installed. Run `flutter doctor`.
2. In your existing clone, run `git fetch origin`, then `git switch -c lakwatsav3 --track origin/lakwatsav3`. If the branch already exists locally, use `git switch lakwatsav3` instead.
3. Run `flutter pub get`.
4. Log into Firebase with `firebase login`, then run:
   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure --project=lakwatsa-bbriones-app --platforms=android,web --android-package-name=com.bbriones.lakwatsa
   ```
   Choose the **existing Firebase app/project** where your Firestore data is stored. This creates `lib/firebase_options.dart`. If `firebase` is missing, use `npm install -g firebase-tools`.
5. In `android/gradle.properties`, add `kotlin.incremental=false` and `kotlin.compiler.execution.strategy=in-process` if you encounter the Windows C:/D: Kotlin cache bug.
6. Run `flutter analyze`. **Do not submit until compile errors are fixed.**
7. Run `flutter run -d chrome` or `flutter run -d <device>`. Grant camera permission for QR scanning.
8. Build the APK: `flutter build apk --debug`. Find it at `build/app/outputs/flutter-apk/app-debug.apk`.
9. Commit `pubspec.lock` and generated Firebase client config on the branch after checking it contains **no private service account key**: `git add lib/firebase_options.dart pubspec.lock; git commit -m "Configure Firebase on new laptop"; git push origin lakwatsav3`.

### Quick smoke test

Register/sign in → Add Item with/without QR → create List & add Items → create Activity → Before Check (manual and/or QR) → Active → Return Check → History and Results.

### Important notes

- `main` is untouched; use branch `lakwatsav3`.
- Old UI-only files in `lib/screens/` remain available as design references, but `lib/main.dart` now imports `lib/v3/ui.dart`.
- The initial GitHub snapshot used `com.example.lakwatsa`. v3 now uses `com.bbriones.lakwatsa`; keep the Android package and Firebase Android app aligned.
- Firestore rules must be reviewed before production deployment.
- A GitHub source branch is not proof of a built APK or fully working demo; run the checks locally.
