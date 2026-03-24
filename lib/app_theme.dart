import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';

class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0B1018);
  static const Color textPrimary = Color(0xFFFAFBFF);
  static const Color textSecondary = Color(0xFFB8C1CF);
  static const Color accentPrimary = Color(0xFF58A6FF);
  static const Color accentSecondaryBlue = Color(0xFF1EA8A7);
  static const Color done = Color(0xFF6CE68D);
  static const Color active = Color(0xFFFFD058);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark(AppFontChoice choice) {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _textTheme(base.textTheme, choice);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentPrimary,
        secondary: AppColors.accentSecondaryBlue,
        surface: Color(0xFF101826),
        error: Color(0xFFFF6969),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
        outline: Color(0x2BFFFFFF),
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF172031),
        contentTextStyle: textTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, AppFontChoice choice) {
    final TextStyle Function({double? fontSize, FontWeight? fontWeight}) family =
        switch (choice) {
      AppFontChoice.systemDefault => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            TextStyle(fontSize: fontSize, fontWeight: fontWeight, height: 1.25),
      AppFontChoice.pressStart2p => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.pressStart2p(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w400,
              height: 1.25,
            ),
      AppFontChoice.specialElite => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.specialElite(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w400,
              height: 1.25,
            ),
      AppFontChoice.cinzel => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.cinzel(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w500,
              height: 1.25,
            ),
    };

    return TextTheme(
      displayLarge: family(fontSize: base.displayLarge?.fontSize ?? 56, fontWeight: FontWeight.w600)
          .copyWith(color: AppColors.textPrimary),
      headlineLarge: family(fontSize: base.headlineLarge?.fontSize ?? 32, fontWeight: FontWeight.w600)
          .copyWith(color: AppColors.textPrimary),
      titleLarge: family(fontSize: base.titleLarge?.fontSize ?? 22, fontWeight: FontWeight.w600)
          .copyWith(color: AppColors.textPrimary),
      titleMedium: family(fontSize: base.titleMedium?.fontSize ?? 16, fontWeight: FontWeight.w600)
          .copyWith(color: AppColors.textPrimary),
      bodyLarge: family(fontSize: base.bodyLarge?.fontSize ?? 16).copyWith(color: AppColors.textPrimary),
      bodyMedium: family(fontSize: base.bodyMedium?.fontSize ?? 14).copyWith(color: AppColors.textPrimary),
      bodySmall: family(fontSize: base.bodySmall?.fontSize ?? 12).copyWith(color: AppColors.textSecondary),
      labelLarge: family(fontSize: base.labelLarge?.fontSize ?? 14, fontWeight: FontWeight.w500)
          .copyWith(color: AppColors.textPrimary),
      labelSmall: family(fontSize: base.labelSmall?.fontSize ?? 11, fontWeight: FontWeight.w500)
          .copyWith(color: AppColors.textSecondary),
    );
  }
}
