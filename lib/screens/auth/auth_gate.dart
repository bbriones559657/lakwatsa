import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.hasData) {
          return const MainScreen();
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
