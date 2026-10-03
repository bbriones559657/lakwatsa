$ErrorActionPreference = 'Stop'
if (-not (Test-Path '.\pubspec.yaml')) { throw 'Run this in the Lakwatsa repo root.' }
flutter doctor
flutter pub get
if (-not (Test-Path '.\lib\firebase_options.dart')) {
    Write-Warning 'Run flutterfire configure --project=lakwatsa-bbriones-app --platforms=android,web --android-package-name=com.bbriones.lakwatsa first.'
    exit 2
}
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Analyze failed. Fix the diagnostics before continuing.' }
flutter build apk --debug
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Host 'APK: build\app\outputs\flutter-apk\app-debug.apk'
