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
    final outline = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: const BorderSide(color: AppColors.ink, width: 2),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: AppColors.ink, width: 2),
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.green,
            brightness: Brightness.light,
          ).copyWith(
            primary: AppColors.ink,
            onPrimary: AppColors.background,
            surface: AppColors.background,
            onSurface: AppColors.ink,
            secondary: AppColors.green,
            outline: AppColors.ink,
          ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        titleSpacing: 20,
        titleTextStyle: AppTextStyles.heading.copyWith(fontSize: 23),
        shape: const Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: outline,
        margin: const EdgeInsets.only(bottom: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.green, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: AppTextStyles.bodyBold,
        hintStyle: AppTextStyles.body,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.background,
          shape: outline,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: AppTextStyles.bodyBold,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink, width: 2),
          shape: outline,
          minimumSize: const Size(48, 48),
          textStyle: AppTextStyles.bodyBold,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: AppTextStyles.bodyBold,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.ink,
        labelStyle: AppTextStyles.bodyBold,
        secondaryLabelStyle: AppTextStyles.bodyBold.copyWith(
          color: AppColors.background,
        ),
        side: const BorderSide(color: AppColors.ink, width: 1.5),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.ink, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.background,
        shape: outline,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.green,
      ),
    );
  }
}
