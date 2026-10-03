import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false, _busy = false, _obscure = true;
  String? _message;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({bool reset = false}) async {
    if (_busy) return;
    if (reset && !_email.text.contains('@')) {
      setState(() => _message = 'Enter your email address first.');
      return;
    }
    if (!reset && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (reset) {
        await auth.sendPasswordResetEmail(email: _email.text.trim());
        if (mounted) {
          setState(
            () => _message =
                'If this email has an account, a reset link will be sent.',
          );
        }
      } else if (_register) {
        await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _message = switch (e.code) {
            'invalid-credential' ||
            'wrong-password' ||
            'user-not-found' => 'Email or password is incorrect.',
            'email-already-in-use' => 'An account already uses that email. Sign in or reset your password.',
            'network-request-failed' =>
              'No connection. Check your internet and retry.',
            'too-many-requests' =>
              'Too many attempts. Please wait before trying again.',
            'operation-not-allowed' =>
              'Enable Email/password sign-in in Firebase Authentication.',
            _ => e.message ?? 'Sign-in failed. Please retry.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to connect. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.backpack_outlined,
                    size: 64,
                    color: AppColors.green,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Lakwatsa',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pack with confidence. Bring everything home.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _register ? 'Create your account' : 'Welcome back',
                    style: AppTextStyles.heading,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v != null &&
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(v.trim())
                        ? null
                        : 'Enter a valid email.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: 'Show or hide password',
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) => v != null && v.length >= 6
                        ? null
                        : 'Use at least 6 characters.',
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(_message!),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit(),
                    child: Text(
                      _busy
                          ? 'Connecting…'
                          : _register
                          ? 'Create account'
                          : 'Sign in',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _message = null;
                          }),
                    child: Text(
                      _register
                          ? 'Already have an account? Sign in'
                          : 'Create an account',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _submit(reset: true),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
