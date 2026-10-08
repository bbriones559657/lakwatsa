import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    this.errorMessage,
    this.onRetry,
    this.isReady = false,
  });

  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.splash,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            const Positioned.fill(
              child: Image(
                image: AssetImage('assets/branding/splash_background.png'),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 620;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: compact ? 22 : 36,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'LAKWATSA / READY TO GO',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.pressStart2p(
                                  fontSize: 7,
                                  color: AppColors.green,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const _SplashMark(),
                                  SizedBox(height: compact ? 22 : 30),
                                  FractionalTranslation(
                                    // The visible wordmark is slightly right of
                                    // center within its transparent PNG canvas.
                                    translation: const Offset(-0.0077, 0),
                                    child: Image.asset(
                                      'assets/branding/lakwatsa_wordmark.png',
                                      key: const Key('splash-wordmark'),
                                      width: constraints.maxWidth < 380
                                          ? constraints.maxWidth - 64
                                          : 310,
                                      height: 78,
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Lakwatsa',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'PACK SMART. SCAN EASY.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.pressStart2p(
                                      fontSize: 8,
                                      height: 1.7,
                                      color: AppColors.background,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Container(
                                    width: 40,
                                    height: 3,
                                    color: AppColors.orange,
                                  ),
                                ],
                              ),
                              if (errorMessage == null)
                                isReady
                                    ? const _StartupReady()
                                    : const _StartupProgress()
                              else
                                _StartupError(
                                  message: errorMessage!,
                                  onRetry: onRetry,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('splash-mark'),
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.orange, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: OverflowBox(
          maxWidth: 280,
          maxHeight: 280,
          child: FractionalTranslation(
            // Compensate for the backpack's off-center visual weight in the
            // supplied PNG without changing the source artwork.
            translation: const Offset(0.0118, 0),
            child: Image.asset(
              'assets/branding/splash_logo.png',
              width: 280,
              height: 280,
              semanticLabel: 'Lakwatsa backpack logo',
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupProgress extends StatelessWidget {
  const _StartupProgress();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Lakwatsa is starting',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Getting your things ready...',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupReady extends StatelessWidget {
  const _StartupReady();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Center(
        child: Text(
          'Ready to go.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.background,
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.background,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            minimumSize: const Size(96, 48),
            foregroundColor: AppColors.background,
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
