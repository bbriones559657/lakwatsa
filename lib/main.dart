import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'v3/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LakwatsaApp());
}
class LakwatsaApp extends StatelessWidget {
  const LakwatsaApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Lakwatsa', debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data == null ? const AuthScreen() : const AppShell();
      },
    ),
  );
}
