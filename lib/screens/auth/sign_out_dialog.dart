import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SignOutDialog extends StatefulWidget {
  final Future<void> Function()? signOut;

  const SignOutDialog({super.key, this.signOut});

  @override
  State<SignOutDialog> createState() => _SignOutDialogState();
}

class _SignOutDialogState extends State<SignOutDialog> {
  bool _working = false;
  String? _error;

  Future<void> _signOut() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      // Keep notification cleanup and Firebase sign-out in the existing flow.
      await (widget.signOut ?? () => AuthService().signOut())();
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = 'Could not sign out. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_working,
      child: AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radius),
          side: const BorderSide(color: AppColors.ink, width: 2),
        ),
        title: Text('Sign out?', style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your saved items, lists, and activities will be here when you '
              'sign in again. Reminders on this device will be cleared.',
              style: AppTextStyles.body,
            ),
            if (_working) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(color: AppColors.green),
              const SizedBox(height: 10),
              Text('Signing out...', style: AppTextStyles.bodyBold),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: AppTextStyles.bodyBold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _working ? null : () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 48),
              foregroundColor: AppColors.ink,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _working ? null : _signOut,
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 48),
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
