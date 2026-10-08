import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final (family, asset) in [
      ('Press Start 2P', 'assets/branding/fonts/PressStart2P-OFL.txt'),
      ('Plus Jakarta Sans', 'assets/branding/fonts/PlusJakartaSans-OFL.txt'),
    ]) {
      final license = await rootBundle.loadString(asset);
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
  runApp(const LakwatsaApp());
}

Future<void> _initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class LakwatsaApp extends StatelessWidget {
  const LakwatsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lakwatsa',
      theme: AppTheme.light,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppSystemUi.light,
        child: child ?? const SizedBox.shrink(),
      ),
      home: StartupGate(initialize: _initializeFirebase),
    );
  }
}

/// Keeps one AuthGate mounted after Firebase is ready. The same splash remains
/// visible while the initial authentication event is still pending.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.initialize,
    this.authGateBuilder,
    this.minimumSplashDuration = const Duration(milliseconds: 1800),
  });

  final Future<void> Function() initialize;
  final WidgetBuilder? authGateBuilder;
  final Duration minimumSplashDuration;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<void> _initialization;
  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeAfterFirstFrame();
  }

  Future<void> _initializeAfterFirstFrame() async {
    // Paint the Flutter splash before Firebase does any platform-channel work.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _initializeWithMinimumVisibility();
  }

  Future<void> _initializeWithMinimumVisibility() async {
    final minimumElapsed = Future<void>.delayed(widget.minimumSplashDuration);
    await widget.initialize();
    if (mounted) setState(() => _firebaseReady = true);
    await minimumElapsed;
  }

  void _retry() {
    setState(() {
      _firebaseReady = false;
      _initialization = _initializeWithMinimumVisibility();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SplashScreen(isReady: _firebaseReady);
        }
        if (snapshot.hasError) {
          return SplashScreen(
            errorMessage: 'Lakwatsa could not start. Please try again.',
            onRetry: _retry,
          );
        }
        return widget.authGateBuilder?.call(context) ?? const AuthGate();
      },
    );
  }
}
