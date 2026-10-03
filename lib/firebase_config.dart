import 'package:firebase_core/firebase_core.dart';

/// Supply registered Firebase client values with --dart-define-from-file.
/// Never put service-account credentials in an application build.
FirebaseOptions get firebaseOptions {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty) {
    throw StateError('Missing Firebase client configuration. See README.md.');
  }
  return const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: 'lakwatsa-bbriones-app',
  );
}
