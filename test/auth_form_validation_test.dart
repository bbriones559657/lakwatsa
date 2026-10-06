import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/screens/auth/auth_form_validation.dart';

void main() {
  group('AuthFormValidation', () {
    test('accepts a valid email after trimming surrounding spaces', () {
      expect(
        AuthFormValidation.validateEmail('  user@example.com  '),
        isNull,
      );
    });

    test('rejects an invalid email', () {
      expect(
        AuthFormValidation.validateEmail('user-at-example'),
        'Enter a valid email address.',
      );
    });

    test('sign in requires a non-empty password', () {
      expect(
        AuthFormValidation.validatePassword('', isRegistration: false),
        'Enter your password.',
      );
    });

    test('registration requires at least six password characters', () {
      expect(
        AuthFormValidation.validatePassword('12345', isRegistration: true),
        'Use at least 6 characters.',
      );
      expect(
        AuthFormValidation.validatePassword('123456', isRegistration: true),
        isNull,
      );
    });

    test('confirm password must match', () {
      expect(
        AuthFormValidation.validateConfirmPassword(
          password: 'secret1',
          confirmation: 'secret2',
        ),
        'Passwords do not match.',
      );
    });

    test('maps common sign-in errors to friendly copy', () {
      expect(
        AuthFormValidation.firebaseErrorMessage('invalid-credential'),
        'Email or password is incorrect.',
      );
      expect(
        AuthFormValidation.firebaseErrorMessage('network-request-failed'),
        'Check your internet connection and try again.',
      );
    });

    test('maps common registration errors to friendly copy', () {
      expect(
        AuthFormValidation.firebaseErrorMessage('email-already-in-use'),
        'An account already exists for this email.',
      );
      expect(
        AuthFormValidation.firebaseErrorMessage('weak-password'),
        'Use a stronger password with at least 6 characters.',
      );
    });

    test('uses a safe generic message for unknown Firebase errors', () {
      expect(
        AuthFormValidation.firebaseErrorMessage('unexpected-code'),
        'Something went wrong. Please try again.',
      );
    });
  });
}
