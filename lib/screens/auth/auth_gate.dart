import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';
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
          return const _AuthLoadingScreen();
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

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Semantics(
          liveRegion: true,
          label: 'Loading Lakwatsa',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'LK',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Lakwatsa',
                    style: AppTextStyles.heading.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Getting your things ready...',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
