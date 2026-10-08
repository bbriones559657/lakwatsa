import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../main_screen.dart';
import '../splash_screen.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatefulWidget {
  final Stream<User?>? authStateChanges;
  final WidgetBuilder? authenticatedBuilder;

  const AuthGate({super.key, this.authStateChanges, this.authenticatedBuilder});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStateChanges;
  String? _previousUserId;

  @override
  void initState() {
    super.initState();
    _authStateChanges =
        widget.authStateChanges ?? AuthService().authStateChanges;
  }

  void _clearPreviousSessionRoutes(String? userId) {
    final previousUserId = _previousUserId;
    _previousUserId = userId;
    if (previousUserId == null || previousUserId == userId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // AuthGate owns the first route. Remove its old session's screens and
      // dialogs even if a notification opened one while sign-out was pending.
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final userId = snapshot.data?.uid;
        _clearPreviousSessionRoutes(userId);
        if (userId != null) {
          return KeyedSubtree(
            key: ValueKey(userId),
            child:
                widget.authenticatedBuilder?.call(context) ??
                const MainScreen(),
          );
        }

        return const SignInScreen();
      },
    );
  }
}
