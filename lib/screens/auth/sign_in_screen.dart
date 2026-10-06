import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'auth_form_validation.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const _errorColor = Color(0xFF9A3F36);
  static const _errorBackground = Color(0xFFF4E4E1);

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final emailFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();
  final confirmPasswordFocusNode = FocusNode();

  final AuthService authService = AuthService();

  bool isRegisterMode = false;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final formIsValid = formKey.currentState?.validate() ?? false;

    if (!formIsValid) {
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text;
    final registerMode = isRegisterMode;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (registerMode) {
        await authService.register(email: email, password: password);
      } else {
        await authService.signIn(email: email, password: password);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = AuthFormValidation.firebaseErrorMessage(error.code);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _clearServerError() {
    if (errorMessage == null || isLoading) {
      return;
    }

    setState(() {
      errorMessage = null;
    });
  }

  void _switchMode() {
    if (isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isRegisterMode = !isRegisterMode;
      errorMessage = null;
      confirmPasswordController.clear();
      obscurePassword = true;
      obscureConfirmPassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _AuthBackgroundDots()),
            LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight = constraints.maxHeight < 720;
                final horizontalPadding = constraints.maxWidth < 390
                    ? 20.0
                    : 28.0;
                final verticalPadding = compactHeight ? 20.0 : 28.0;
                final minimumContentHeight =
                    constraints.maxHeight > verticalPadding * 2
                    ? constraints.maxHeight - verticalPadding * 2
                    : 0.0;

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    compactHeight ? 24 : 32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minimumContentHeight,
                        maxWidth: 420,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        const _BrandMark(),
                        SizedBox(height: compactHeight ? 12 : 16),
                        Text(
                          'Lakwatsa',
                          style: AppTextStyles.heading.copyWith(
                            fontSize: compactHeight ? 34 : 38,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'pack smart. scan easy.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.pixel.copyWith(fontSize: 8),
                        ),
                        SizedBox(height: compactHeight ? 14 : 18),
                        Container(
                          width: 36,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 28 : 48),
                        _PixelCard(
                          child: Form(
                            key: formKey,
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isRegisterMode
                                        ? 'Create your account'
                                        : 'Sign in to continue',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    isRegisterMode
                                        ? 'Keep your items and lists ready wherever you go.'
                                        : 'Your items. Your lists. Always ready.',
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(height: 2, color: AppColors.ink),
                                  const SizedBox(height: 18),
                                  const _FieldLabel('Email'),
                                  const SizedBox(height: 7),
                                  _AuthTextField(
                                    controller: emailController,
                                    focusNode: emailFocusNode,
                                    hintText: 'you@example.com',
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    onChanged: (_) => _clearServerError(),
                                    validator: (value) {
                                      return AuthFormValidation.validateEmail(
                                        value ?? '',
                                      );
                                    },
                                    onSubmitted: (_) {
                                      passwordFocusNode.requestFocus();
                                    },
                                  ),
                                  const SizedBox(height: 15),
                                  const _FieldLabel('Password'),
                                  const SizedBox(height: 7),
                                  _AuthTextField(
                                    controller: passwordController,
                                    focusNode: passwordFocusNode,
                                    hintText: isRegisterMode
                                        ? 'At least 6 characters'
                                        : 'Enter your password',
                                    obscureText: obscurePassword,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    textInputAction: isRegisterMode
                                        ? TextInputAction.next
                                        : TextInputAction.done,
                                    autofillHints: [
                                      isRegisterMode
                                          ? AutofillHints.newPassword
                                          : AutofillHints.password,
                                    ],
                                    onChanged: (_) => _clearServerError(),
                                    validator: (value) {
                                      return AuthFormValidation.validatePassword(
                                        value ?? '',
                                        isRegistration: isRegisterMode,
                                      );
                                    },
                                    onSubmitted: (_) {
                                      if (isRegisterMode) {
                                        confirmPasswordFocusNode.requestFocus();
                                      } else {
                                        _submit();
                                      }
                                    },
                                    suffix: _VisibilityButton(
                                      isObscured: obscurePassword,
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              setState(() {
                                                obscurePassword =
                                                    !obscurePassword;
                                              });
                                            },
                                    ),
                                  ),
                                  if (isRegisterMode) ...[
                                    const SizedBox(height: 15),
                                    const _FieldLabel('Confirm Password'),
                                    const SizedBox(height: 7),
                                    _AuthTextField(
                                      controller: confirmPasswordController,
                                      focusNode: confirmPasswordFocusNode,
                                      hintText: 'Re-enter your password',
                                      obscureText: obscureConfirmPassword,
                                      enableSuggestions: false,
                                      autocorrect: false,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      onChanged: (_) => _clearServerError(),
                                      validator: (value) {
                                        return AuthFormValidation
                                            .validateConfirmPassword(
                                              password:
                                                  passwordController.text,
                                              confirmation: value ?? '',
                                            );
                                      },
                                      onSubmitted: (_) {
                                        _submit();
                                      },
                                      suffix: _VisibilityButton(
                                        isObscured: obscureConfirmPassword,
                                        onPressed: isLoading
                                            ? null
                                            : () {
                                                setState(() {
                                                  obscureConfirmPassword =
                                                      !obscureConfirmPassword;
                                                });
                                              },
                                      ),
                                    ),
                                  ],
                                  if (errorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    _ErrorMessage(message: errorMessage!),
                                  ],
                                  const SizedBox(height: 20),
                                  _PrimaryButton(
                                    text: isRegisterMode
                                        ? 'Create Account'
                                        : 'Sign In',
                                    isLoading: isLoading,
                                    onPressed: isLoading ? null : _submit,
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton(
                                      onPressed: isLoading ? null : _switchMode,
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        foregroundColor: AppColors.ink,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: Text(
                                        isRegisterMode
                                            ? 'Already have an account? Sign in'
                                            : 'New to Lakwatsa? Create account',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodyBold.copyWith(
                                          fontSize: 12,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 20 : 28),
                        Text(
                          'your items. always ready.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.pixel.copyWith(
                            fontSize: 7,
                            color: AppColors.muted.withValues(alpha: .65),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackgroundDots extends StatelessWidget {
  const _AuthBackgroundDots();

  static const positions = <Alignment>[
    Alignment(-.84, -.88),
    Alignment(.70, -.80),
    Alignment(-.72, -.52),
    Alignment(.82, -.57),
    Alignment(-.66, -.02),
    Alignment(.72, -.08),
    Alignment(-.88, .38),
    Alignment(.90, .33),
    Alignment(-.56, .72),
    Alignment(.58, .76),
    Alignment(.92, -.28),
    Alignment(-.92, -.22),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: positions.map((alignment) {
          return Align(
            alignment: alignment,
            child: Container(
              width: 4,
              height: 4,
              color: AppColors.ink.withValues(alpha: .06),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 3,
            top: 3,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.ink, width: 2.5),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: AppColors.ink, offset: Offset(5, 5)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'LK',
                style: AppTextStyles.heading.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Positioned(left: 0, top: 0, child: _PixelCorner()),
          const Positioned(right: 0, top: 0, child: _PixelCorner()),
          const Positioned(left: 0, bottom: 0, child: _PixelCorner()),
          const Positioned(right: 0, bottom: 0, child: _PixelCorner()),
        ],
      ),
    );
  }
}

class _PixelCard extends StatelessWidget {
  final Widget child;

  const _PixelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.ink, width: 2.5),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(5, 5)),
            ],
          ),
          child: child,
        ),
        const Positioned(left: -3, top: -3, child: _PixelCorner()),
        const Positioned(right: -3, top: -3, child: _PixelCorner()),
        const Positioned(left: -3, bottom: -3, child: _PixelCorner()),
        const Positioned(right: -3, bottom: -3, child: _PixelCorner()),
      ],
    );
  }
}

class _PixelCorner extends StatelessWidget {
  const _PixelCorner();

  @override
  Widget build(BuildContext context) {
    return Container(width: 6, height: 6, color: AppColors.ink);
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final String? Function(String?) validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _AuthTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.body.copyWith(fontSize: 13),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        errorStyle: AppTextStyles.body.copyWith(
          color: _SignInScreenState._errorColor,
          fontSize: 11,
          height: 1.25,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.green, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: _SignInScreenState._errorColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: _SignInScreenState._errorColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _VisibilityButton extends StatelessWidget {
  final bool isObscured;
  final VoidCallback? onPressed;

  const _VisibilityButton({
    required this.isObscured,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: isObscured ? 'Show password' : 'Hide password',
      icon: Icon(
        isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.ink,
        size: 20,
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _SignInScreenState._errorBackground,
          border: Border.all(
            color: _SignInScreenState._errorColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: _SignInScreenState._errorColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(
                  color: _SignInScreenState._errorColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.text,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : .6,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: AppColors.green, offset: Offset(4, 4)),
          ],
        ),
        child: Material(
          color: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: AppColors.ink, width: 2.5),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 48,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: isLoading
                      ? Row(
                          key: const ValueKey('loading'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Please wait...',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: AppColors.background,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          text,
                          key: const ValueKey('label'),
                          style: AppTextStyles.bodyBold.copyWith(
                            color: AppColors.background,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}