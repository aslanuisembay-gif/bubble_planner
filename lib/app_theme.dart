import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Цвета и типографика из artifact.json (src/index.css + src/App.css).
/// Соответствуют React-версии: :root и body font.
class AppColors {
  AppColors._();

  // index.css :root (базовые)
  static const Color bgColor = Color(0xFF07070C); // hsl(240, 15%, 3%) ≈ #07070c
  static const Color surfaceColor = Color(0x991A1A24); // hsla(240, 15%, 10%, 0.6)
  static const Color borderColor = Color(0x1AFFD700); // hsla(45, 100%, 50%, 0.1)
  static const Color textPrimary = Color(0xFFFAFAFA); // hsl(0, 0%, 98%)
  static const Color textSecondary = Color(0xFFB8B8BF); // hsl(240, 5%, 75%)
  static const Color accentPrimaryGold = Color(0xFFFFD700); // hsl(45, 100%, 50%) Deep Gold
  static const Color accentSecondaryBlue = Color(0xFF1E5A8C); // hsl(210, 80%, 35%) Deep Blue

  // App.css :root (используются в UI)
  static const Color bg = Color(0xFF0D0D0D);
  static const Color surface = Color(0xCC1A1A1A); // rgba(26, 26, 26, 0.8)
  static const Color border = Color(0x1AFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // accent-primary: var(--user-accent, #8a2be2)
  static const Color accentPrimary = Color(0xFF8A2BE2); // BlueViolet
  // accent-secondary: #ffb800
  static const Color accentSecondary = Color(0xFFFFB800);

  // Статусы (Done / Active)
  static const Color done = Color(0xFF5BFF7F);
  static const Color active = Color(0xFFFFD54F);

  // Фон градиента (Bubbles view)
  static const Color gradientTop = Color(0xFF0D0D0D);
  static const Color gradientMid = Color(0xFF0B0F1D);
  static const Color gradientBottom = Color(0xFF1A1930);

  // Модалки / листы
  static const Color sheetBackground = Color(0xFF12121A);
  static const Color divider = Color(0x22FFFFFF);

  // Иконка приложения (голубой акцент из index.css --accent-secondary)
  static const Color appIconStart = Color(0xFF276DFF);
  static const Color appIconEnd = Color(0xFF1E5A8C);

  // Цвета категорий пузырей (как в React utils.getCategoryColor)
  static const Color categoryShopping = Color(0xFF8E5AFF);
  static const Color categoryWork = Color(0xFFE05A5A);
  static const Color categoryHome = Color(0xFF3FA7D6);
  static const Color categoryHealth = Color(0xFF4CAF50);
  static const Color categoryKids = Color(0xFFFFA726);
  static const Color categoryFinance = Color(0xFF26C6DA);
  static const Color categoryDefault = Color(0xFF7E7E8A);
}

/// Тема приложения в стиле React-версии (Outfit + Inter, тёмная палитра).
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.dark(
        primary: AppColors.accentPrimary,
        secondary: AppColors.accentSecondary,
        surface: const Color(0xFF1A1A1A),
        error: Colors.redAccent,
        onPrimary: AppColors.textOnAccent,
        onSecondary: AppColors.textOnAccent,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
        outline: AppColors.border,
      ),
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.inter(color: AppColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.textOnAccent,
        ),
      ),
    );
  }

  /// body: var(--font-main) = Inter; заголовки — Outfit (--font-heading).
  static TextTheme _textTheme(TextTheme base) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.displayLarge?.fontSize ?? 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      displayMedium: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.displayMedium?.fontSize ?? 45,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.displaySmall?.fontSize ?? 36,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.headlineLarge?.fontSize ?? 32,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.headlineMedium?.fontSize ?? 28,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.headlineSmall?.fontSize ?? 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.titleLarge?.fontSize ?? 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.titleMedium?.fontSize ?? 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: base.titleSmall?.fontSize ?? 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: base.bodyLarge?.fontSize ?? 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
      ),
      bodyMedium: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: base.bodyMedium?.fontSize ?? 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: base.bodySmall?.fontSize ?? 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: base.labelLarge?.fontSize ?? 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: base.labelMedium?.fontSize ?? 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: base.labelSmall?.fontSize ?? 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
