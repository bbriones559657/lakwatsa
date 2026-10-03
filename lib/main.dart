import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/auth_screen.dart';
import 'app/packing_app.dart';
import 'firebase_config.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    await ReminderService.instance.initialize();
  } catch (_) {
    startupError = 'Firebase could not initialize. Check this app’s Firebase configuration and restart.';
  }
  runApp(LakwatsaApp(startupError: startupError));
}

class LakwatsaApp extends StatelessWidget {
  final String? startupError;
  const LakwatsaApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lakwatsa',
      theme: AppTheme.light,
      home: startupError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(startupError!, textAlign: TextAlign.center),
                ),
              ),
            )
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Scaffold(
                    body: Center(
                      child: Text(
                        'Unable to load your account. Restart and try again.',
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final user = snapshot.data;
                return user == null
                    ? const AuthScreen()
                    : PackingApp(key: ValueKey(user.uid), user: user);
              },
            ),
    );
  }
}
