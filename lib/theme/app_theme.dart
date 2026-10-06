import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFFBF7F5);
  static const ink = Color(0xFF1C1918);
  static const muted = Color(0xFF6F6863);
  static const card = Color(0xFFEDE0D9);
  static const green = Color(0xFF4A8C72);
  static const orange = Color(0xFFC4853A);
}

class AppMetrics {
  static const pagePadding = 20.0;
  static const topBarHeight = 56.0;
  static const bottomNavHeight = 56.0;
  static const touchTarget = 44.0;
  static const primaryButtonHeight = 48.0;
  static const radius = 4.0;
  static const borderWidth = 2.0;
  static const strongBorderWidth = 2.5;
}

class AppTextStyles {
  static final heading = GoogleFonts.plusJakartaSans(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static final bodyBold = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static final body = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    color: AppColors.muted,
  );

  static final navSelected = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static final nav = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    color: AppColors.muted,
  );

  static final pixel = GoogleFonts.pressStart2p(
    fontSize: 7,
    color: AppColors.muted,
  );

  static final pixelDark = GoogleFonts.pressStart2p(
    fontSize: 6,
    color: AppColors.ink,
  );

  static final pixelWhite = GoogleFonts.pressStart2p(
    fontSize: 6,
    color: AppColors.background,
  );
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),
    );
  }
}
