class AuthFormValidation {
  AuthFormValidation._();

  static final RegExp _emailPattern = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );

  static String? validateEmail(String value) {
    final email = value.trim();

    if (email.isEmpty) {
      return 'Enter your email address.';
    }

    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  static String? validatePassword(
    String value, {
    required bool isRegistration,
  }) {
    if (value.isEmpty) {
      return 'Enter your password.';
    }

    if (isRegistration && value.length < 6) {
      return 'Use at least 6 characters.';
    }

    return null;
  }

  static String? validateConfirmPassword({
    required String password,
    required String confirmation,
  }) {
    if (confirmation.isEmpty) {
      return 'Confirm your password.';
    }

    if (password != confirmation) {
      return 'Passwords do not match.';
    }

    return null;
  }

  static String firebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a little while.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Email and password sign-in is unavailable right now.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
