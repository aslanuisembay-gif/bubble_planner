import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Выбор шрифта (Настройки → Оформление).
enum AppFontChoice {
  systemDefault,
  pressStart2p,
  specialElite,
  cinzel,
  dancingScript,
  caveat,
  kalam,
  pacifico,
  rubik,
  spaceGrotesk,
  outfit,
  nunito,
  playfairDisplay,
  merriweather,
  inter,
  manrope,
  sora,
  ibmPlexSans,
  firaSans,
  josefinSans,
  bebasNeue,
  libreBaskerville,
}

/// Доступные цветовые темы (меняются в Настройки → Оформление).
enum AppColorPaletteId {
  classic,
  wellnessMint,
  softLavender,
  oceanBreeze,
  sunsetCoral,
  midnightNeon,
  forestMoss,
  monochromeInk,
  peachSorbet,
}

/// Семантические цвета приложения (тёмная «классика», светлые wellness-стили и др.).
@immutable
class BubblePlannerColors extends ThemeExtension<BubblePlannerColors> {
  const BubblePlannerColors({
    required this.brightness,
    required this.backgroundGradient,
    required this.scaffold,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.talkAccent,
    required this.success,
    required this.warning,
    required this.glassFill,
    required this.glassBorder,
    required this.glassIcon,
    required this.navBarBg,
    required this.navInactive,
    required this.navActiveHighlight,
    required this.brandGradientStart,
    required this.brandGradientEnd,
    required this.modalSurface,
    required this.modalBorder,
    required this.micSelectedRing,
    required this.segmentActive,
    required this.taskSheetGradient,
    required this.taskCardBg,
    required this.toolAccentNotes,
    required this.toolAccentPomodoro,
    required this.footerToolsFill,
    required this.footerToolsBorder,
    required this.loginPanelFill,
    required this.loginPanelBorder,
    required this.loginGlow,
    required this.loginLogoGradient,
    required this.loginLogoShadow,
    required this.navShadow,
  });

  final Brightness brightness;
  final List<Color> backgroundGradient;
  final Color scaffold;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color talkAccent;
  final Color success;
  final Color warning;
  final Color glassFill;
  final Color glassBorder;
  final Color glassIcon;
  final Color navBarBg;
  final Color navInactive;
  final Color navActiveHighlight;
  final Color brandGradientStart;
  final Color brandGradientEnd;
  final Color modalSurface;
  final Color modalBorder;
  final Color micSelectedRing;
  final Color segmentActive;
  final List<Color> taskSheetGradient;
  final Color taskCardBg;
  final Color toolAccentNotes;
  final Color toolAccentPomodoro;
  final Color footerToolsFill;
  final Color footerToolsBorder;
  final Color loginPanelFill;
  final Color loginPanelBorder;
  final Color loginGlow;
  final List<Color> loginLogoGradient;
  final Color loginLogoShadow;
  final Color navShadow;

  /// Слабая заливка карточек поверх градиента (список задач).
  Color get listCardFill => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.05);

  Color get listCardBorder => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);

  Color get listHairline => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.15)
      : Colors.black.withValues(alpha: 0.12);

  /// Второстепенный текст на том же фоне, что и [listCardFill].
  Color get listTextMuted => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.5)
      : textSecondary;

  Color get listIconMuted => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.54)
      : textSecondary.withValues(alpha: 0.8);

  static BubblePlannerColors of(BuildContext context) {
    return Theme.of(context).extension<BubblePlannerColors>() ?? classic;
  }

  static BubblePlannerColors fromId(AppColorPaletteId id) {
    return switch (id) {
      AppColorPaletteId.classic => classic,
      AppColorPaletteId.wellnessMint => wellnessMint,
      AppColorPaletteId.softLavender => softLavender,
      AppColorPaletteId.oceanBreeze => oceanBreeze,
      AppColorPaletteId.sunsetCoral => sunsetCoral,
      AppColorPaletteId.midnightNeon => midnightNeon,
      AppColorPaletteId.forestMoss => forestMoss,
      AppColorPaletteId.monochromeInk => monochromeInk,
      AppColorPaletteId.peachSorbet => peachSorbet,
    };
  }

  /// Тёмная «как было»: ночной градиент, фиолетовые акценты.
  static const BubblePlannerColors classic = BubblePlannerColors(
    brightness: Brightness.dark,
    backgroundGradient: [
      Color(0xFF0A0612),
      Color(0xFF12081F),
      Color(0xFF1A0F08),
    ],
    scaffold: Color(0xFF0B1018),
    primary: Color(0xFF58A6FF),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF1EA8A7),
    surface: Color(0xFF101826),
    surfaceElevated: Color(0xFF151018),
    textPrimary: Color(0xFFFAFBFF),
    textSecondary: Color(0xFFB8C1CF),
    talkAccent: Color(0xFF8B5CF6),
    success: Color(0xFF22C55E),
    warning: Color(0xFFFBBF24),
    glassFill: Color(0x1AFFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    glassIcon: Color(0xEBFFFFFF),
    navBarBg: Color(0xEB0B1018),
    navInactive: Color(0x8AFFFFFF),
    navActiveHighlight: Color(0x14FFFFFF),
    brandGradientStart: Color(0xFFB794F6),
    brandGradientEnd: Color(0xFF6B21A8),
    modalSurface: Color(0xFF151018),
    modalBorder: Color(0x1FFFFFFF),
    micSelectedRing: Color(0x5C7C4DFF),
    segmentActive: Color(0xFF4F89FF),
    taskSheetGradient: [Color(0xFF141516), Color(0xFF101113)],
    /// Карточка списка внутри «пузыря» и тёмной темы: тот же уровень, что [surfaceElevated], не светлый лист.
    taskCardBg: Color(0xFF151018),
    toolAccentNotes: Color(0xFF60A5FA),
    toolAccentPomodoro: Color(0xFFE35A52),
    footerToolsFill: Color(0x3D7C4DFF),
    footerToolsBorder: Color(0xFF9D7CFF),
    loginPanelFill: Color(0x14FFFFFF),
    loginPanelBorder: Color(0x1FFFFFFF),
    loginGlow: Color(0x409D00FF),
    loginLogoGradient: [Color(0xFFB026FF), Color(0xFF5C0D9E)],
    loginLogoShadow: Color(0x8C9D00FF),
    navShadow: Color(0x8A000000),
  );

  /// Светлая «wellness»: мятный фон, белые карточки, мягкие тени (как в референсе).
  static const BubblePlannerColors wellnessMint = BubblePlannerColors(
    brightness: Brightness.light,
    backgroundGradient: [
      Color(0xFFE8F8F2),
      Color(0xFFDFF5EC),
      Color(0xFFE5F5EF),
    ],
    scaffold: Color(0xFFE8F5F0),
    primary: Color(0xFF2EB88A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF5ECFB0),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF6B7280),
    talkAccent: Color(0xFF1A9D78),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x33000000),
    glassIcon: Color(0xE01C1C1E),
    navBarBg: Color(0xF5FFFFFF),
    navInactive: Color(0xFF9CA3AF),
    navActiveHighlight: Color(0x142EB88A),
    brandGradientStart: Color(0xFF5ECFB0),
    brandGradientEnd: Color(0xFF2EB88A),
    modalSurface: Color(0xFFFFFFFF),
    modalBorder: Color(0x1F000000),
    micSelectedRing: Color(0x482EB88A),
    segmentActive: Color(0xFF2EB88A),
    taskSheetGradient: [Color(0xFFE8F8F2), Color(0xFFD8F0E8)],
    taskCardBg: Color(0xFFFFFFFF),
    toolAccentNotes: Color(0xFF3B9FE8),
    toolAccentPomodoro: Color(0xFFE85D5D),
    footerToolsFill: Color(0x332EB88A),
    footerToolsBorder: Color(0xFF5ECFB0),
    loginPanelFill: Color(0xF5FFFFFF),
    loginPanelBorder: Color(0x28000000),
    loginGlow: Color(0x182EB88A),
    loginLogoGradient: [Color(0xFF5ECFB0), Color(0xFF2EB88A)],
    loginLogoShadow: Color(0x402EB88A),
    navShadow: Color(0x12000000),
  );

  static const BubblePlannerColors softLavender = BubblePlannerColors(
    brightness: Brightness.light,
    backgroundGradient: [
      Color(0xFFF3EEF9),
      Color(0xFFEDE7F6),
      Color(0xFFF0EBFA),
    ],
    scaffold: Color(0xFFF3EEF9),
    primary: Color(0xFF8B5CF6),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFA78BFA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF6B7280),
    talkAccent: Color(0xFF7C3AED),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x33000000),
    glassIcon: Color(0xE01C1C1E),
    navBarBg: Color(0xF5FFFFFF),
    navInactive: Color(0xFF9CA3AF),
    navActiveHighlight: Color(0x148B5CF6),
    brandGradientStart: Color(0xFFC4B5FD),
    brandGradientEnd: Color(0xFF7C3AED),
    modalSurface: Color(0xFFFFFFFF),
    modalBorder: Color(0x1F000000),
    micSelectedRing: Color(0x488B5CF6),
    segmentActive: Color(0xFF8B5CF6),
    taskSheetGradient: [Color(0xFFF3EEF9), Color(0xFFE8E0F4)],
    taskCardBg: Color(0xFFFFFFFF),
    toolAccentNotes: Color(0xFF60A5FA),
    toolAccentPomodoro: Color(0xFFF472B6),
    footerToolsFill: Color(0x338B5CF6),
    footerToolsBorder: Color(0xFFA78BFA),
    loginPanelFill: Color(0xF5FFFFFF),
    loginPanelBorder: Color(0x28000000),
    loginGlow: Color(0x188B5CF6),
    loginLogoGradient: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    loginLogoShadow: Color(0x408B5CF6),
    navShadow: Color(0x12000000),
  );

  static const BubblePlannerColors oceanBreeze = BubblePlannerColors(
    brightness: Brightness.light,
    backgroundGradient: [
      Color(0xFFE8F4FC),
      Color(0xFFDCEEF9),
      Color(0xFFE5F2FA),
    ],
    scaffold: Color(0xFFE8F4FC),
    primary: Color(0xFF0EA5E9),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF38BDF8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF6B7280),
    talkAccent: Color(0xFF0284C7),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x33000000),
    glassIcon: Color(0xE01C1C1E),
    navBarBg: Color(0xF5FFFFFF),
    navInactive: Color(0xFF9CA3AF),
    navActiveHighlight: Color(0x140EA5E9),
    brandGradientStart: Color(0xFF7DD3FC),
    brandGradientEnd: Color(0xFF0284C7),
    modalSurface: Color(0xFFFFFFFF),
    modalBorder: Color(0x1F000000),
    micSelectedRing: Color(0x480EA5E9),
    segmentActive: Color(0xFF0EA5E9),
    taskSheetGradient: [Color(0xFFE8F4FC), Color(0xFFDCEEF9)],
    taskCardBg: Color(0xFFFFFFFF),
    toolAccentNotes: Color(0xFF6366F1),
    toolAccentPomodoro: Color(0xFFFB7185),
    footerToolsFill: Color(0x330EA5E9),
    footerToolsBorder: Color(0xFF38BDF8),
    loginPanelFill: Color(0xF5FFFFFF),
    loginPanelBorder: Color(0x28000000),
    loginGlow: Color(0x180EA5E9),
    loginLogoGradient: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    loginLogoShadow: Color(0x400EA5E9),
    navShadow: Color(0x12000000),
  );

  static const BubblePlannerColors sunsetCoral = BubblePlannerColors(
    brightness: Brightness.light,
    backgroundGradient: [
      Color(0xFFFFEFEA),
      Color(0xFFFFE3DB),
      Color(0xFFFFF3EE),
    ],
    scaffold: Color(0xFFFFEFEA),
    primary: Color(0xFFEF6B5A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFF59E7B),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F1B1A),
    textSecondary: Color(0xFF6F5F5C),
    talkAccent: Color(0xFFE25544),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x33000000),
    glassIcon: Color(0xE01F1B1A),
    navBarBg: Color(0xF5FFFFFF),
    navInactive: Color(0xFFA3A3A3),
    navActiveHighlight: Color(0x14EF6B5A),
    brandGradientStart: Color(0xFFF59E7B),
    brandGradientEnd: Color(0xFFEF6B5A),
    modalSurface: Color(0xFFFFFFFF),
    modalBorder: Color(0x1F000000),
    micSelectedRing: Color(0x48EF6B5A),
    segmentActive: Color(0xFFEF6B5A),
    taskSheetGradient: [Color(0xFFFFEFEA), Color(0xFFFFE5DE)],
    taskCardBg: Color(0xFFFFFFFF),
    toolAccentNotes: Color(0xFFFB7185),
    toolAccentPomodoro: Color(0xFFE85D5D),
    footerToolsFill: Color(0x33EF6B5A),
    footerToolsBorder: Color(0xFFF59E7B),
    loginPanelFill: Color(0xF5FFFFFF),
    loginPanelBorder: Color(0x28000000),
    loginGlow: Color(0x18EF6B5A),
    loginLogoGradient: [Color(0xFFF59E7B), Color(0xFFEF6B5A)],
    loginLogoShadow: Color(0x40EF6B5A),
    navShadow: Color(0x12000000),
  );

  static const BubblePlannerColors midnightNeon = BubblePlannerColors(
    brightness: Brightness.dark,
    backgroundGradient: [
      Color(0xFF040918),
      Color(0xFF071027),
      Color(0xFF0B1A34),
    ],
    scaffold: Color(0xFF050D1C),
    primary: Color(0xFF00E5FF),
    onPrimary: Color(0xFF00121C),
    secondary: Color(0xFF8B5CF6),
    surface: Color(0xFF0C1830),
    surfaceElevated: Color(0xFF12203D),
    textPrimary: Color(0xFFEAF6FF),
    textSecondary: Color(0xFF9BB3C9),
    talkAccent: Color(0xFF22D3EE),
    success: Color(0xFF22C55E),
    warning: Color(0xFFFBBF24),
    glassFill: Color(0x1AFFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    glassIcon: Color(0xEBFFFFFF),
    navBarBg: Color(0xE6050D1C),
    navInactive: Color(0x8AEAF6FF),
    navActiveHighlight: Color(0x1400E5FF),
    brandGradientStart: Color(0xFF00E5FF),
    brandGradientEnd: Color(0xFF8B5CF6),
    modalSurface: Color(0xFF12203D),
    modalBorder: Color(0x1FFFFFFF),
    micSelectedRing: Color(0x5C00E5FF),
    segmentActive: Color(0xFF00E5FF),
    taskSheetGradient: [Color(0xFF0B1A34), Color(0xFF081326)],
    taskCardBg: Color(0xFF12203D),
    toolAccentNotes: Color(0xFF22D3EE),
    toolAccentPomodoro: Color(0xFFF472B6),
    footerToolsFill: Color(0x3300E5FF),
    footerToolsBorder: Color(0xFF8B5CF6),
    loginPanelFill: Color(0x1AFFFFFF),
    loginPanelBorder: Color(0x1FFFFFFF),
    loginGlow: Color(0x4000E5FF),
    loginLogoGradient: [Color(0xFF00E5FF), Color(0xFF8B5CF6)],
    loginLogoShadow: Color(0x8C00E5FF),
    navShadow: Color(0x8A000000),
  );

  static const BubblePlannerColors forestMoss = BubblePlannerColors(
    brightness: Brightness.light,
    backgroundGradient: [
      Color(0xFFE8F1E4),
      Color(0xFFDDEAD6),
      Color(0xFFEFF6EB),
    ],
    scaffold: Color(0xFFE8F1E4),
    primary: Color(0xFF3F7D3B),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF6A9C5E),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1D251C),
    textSecondary: Color(0xFF5A6A58),
    talkAccent: Color(0xFF2F6D2C),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x33000000),
    glassIcon: Color(0xE01D251C),
    navBarBg: Color(0xF5FFFFFF),
    navInactive: Color(0xFF8A9A86),
    navActiveHighlight: Color(0x143F7D3B),
    brandGradientStart: Color(0xFF6A9C5E),
    brandGradientEnd: Color(0xFF3F7D3B),
    modalSurface: Color(0xFFFFFFFF),
    modalBorder: Color(0x1F000000),
    micSelectedRing: Color(0x483F7D3B),
    segmentActive: Color(0xFF3F7D3B),
    taskSheetGradient: [Color(0xFFE8F1E4), Color(0xFFDCE8D4)],
    taskCardBg: Color(0xFFFFFFFF),
    toolAccentNotes: Color(0xFF16A34A),
    toolAccentPomodoro: Color(0xFFD97706),
    footerToolsFill: Color(0x333F7D3B),
    footerToolsBorder: Color(0xFF6A9C5E),
    loginPanelFill: Color(0xF5FFFFFF),
    loginPanelBorder: Color(0x28000000),
    loginGlow: Color(0x183F7D3B),
    loginLogoGradient: [Color(0xFF6A9C5E), Color(0xFF3F7D3B)],
    loginLogoShadow: Color(0x403F7D3B),
    navShadow: Color(0x12000000),
  );

  static const BubblePlannerColors monochromeInk = BubblePlannerColors(
    brightness: Brightness.dark,
    backgroundGradient: [
      Color(0xFF0B0B0B),
      Color(0xFF121212),
      Color(0xFF1A1A1A),
    ],
    scaffold: Color(0xFF0C0C0C),
    primary: Color(0xFFE5E5E5),
    onPrimary: Color(0xFF111111),
    secondary: Color(0xFFA3A3A3),
    surface: Color(0xFF151515),
    surfaceElevated: Color(0xFF1D1D1D),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFB4B4B6),
    talkAccent: Color(0xFFD4D4D8),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    glassFill: Color(0x1AFFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    glassIcon: Color(0xEBFFFFFF),
    navBarBg: Color(0xEB0C0C0C),
    navInactive: Color(0x8AF4F4F5),
    navActiveHighlight: Color(0x14FFFFFF),
    brandGradientStart: Color(0xFFE5E5E5),
    brandGradientEnd: Color(0xFFA3A3A3),
    modalSurface: Color(0xFF1D1D1D),
    modalBorder: Color(0x1FFFFFFF),
    micSelectedRing: Color(0x5CE5E5E5),
    segmentActive: Color(0xFFCACACA),
    taskSheetGradient: [Color(0xFF1A1A1A), Color(0xFF121212)],
    taskCardBg: Color(0xFF1D1D1D),
    toolAccentNotes: Color(0xFFA3A3A3),
    toolAccentPomodoro: Color(0xFFF87171),
    footerToolsFill: Color(0x33FFFFFF),
    footerToolsBorder: Color(0xFFCACACA),
    loginPanelFill: Color(0x1AFFFFFF),
    loginPanelBorder: Color(0x1FFFFFFF),
    loginGlow: Color(0x40FFFFFF),
    loginLogoGradient: [Color(0xFFE5E5E5), Color(0xFFA3A3A3)],
    loginLogoShadow: Color(0x8CE5E5E5),
    navShadow: Color(0x8A000000),
  );

  static const BubblePlannerColors peachSorbet = BubblePlannerColors(
    brightness: Brightness.light,
    backgroundGradient: [
      Color(0xFFFFF6EE),
      Color(0xFFFFEFE2),
      Color(0xFFFFFAF4),
    ],
    scaffold: Color(0xFFFFF6EE),
    primary: Color(0xFFFF8A5B),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFB088),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2A1F1A),
    textSecondary: Color(0xFF7A655C),
    talkAccent: Color(0xFFFB923C),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x33000000),
    glassIcon: Color(0xE02A1F1A),
    navBarBg: Color(0xF5FFFFFF),
    navInactive: Color(0xFFB5A29A),
    navActiveHighlight: Color(0x14FF8A5B),
    brandGradientStart: Color(0xFFFFB088),
    brandGradientEnd: Color(0xFFFF8A5B),
    modalSurface: Color(0xFFFFFFFF),
    modalBorder: Color(0x1F000000),
    micSelectedRing: Color(0x48FF8A5B),
    segmentActive: Color(0xFFFF8A5B),
    taskSheetGradient: [Color(0xFFFFF6EE), Color(0xFFFFEDDF)],
    taskCardBg: Color(0xFFFFFFFF),
    toolAccentNotes: Color(0xFF60A5FA),
    toolAccentPomodoro: Color(0xFFF97316),
    footerToolsFill: Color(0x33FF8A5B),
    footerToolsBorder: Color(0xFFFFB088),
    loginPanelFill: Color(0xF5FFFFFF),
    loginPanelBorder: Color(0x28000000),
    loginGlow: Color(0x18FF8A5B),
    loginLogoGradient: [Color(0xFFFFB088), Color(0xFFFF8A5B)],
    loginLogoShadow: Color(0x40FF8A5B),
    navShadow: Color(0x12000000),
  );

  @override
  BubblePlannerColors copyWith({
    Brightness? brightness,
    List<Color>? backgroundGradient,
    Color? scaffold,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? surface,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? talkAccent,
    Color? success,
    Color? warning,
    Color? glassFill,
    Color? glassBorder,
    Color? glassIcon,
    Color? navBarBg,
    Color? navInactive,
    Color? navActiveHighlight,
    Color? brandGradientStart,
    Color? brandGradientEnd,
    Color? modalSurface,
    Color? modalBorder,
    Color? micSelectedRing,
    Color? segmentActive,
    List<Color>? taskSheetGradient,
    Color? taskCardBg,
    Color? toolAccentNotes,
    Color? toolAccentPomodoro,
    Color? footerToolsFill,
    Color? footerToolsBorder,
    Color? loginPanelFill,
    Color? loginPanelBorder,
    Color? loginGlow,
    List<Color>? loginLogoGradient,
    Color? loginLogoShadow,
    Color? navShadow,
  }) {
    return BubblePlannerColors(
      brightness: brightness ?? this.brightness,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      scaffold: scaffold ?? this.scaffold,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      talkAccent: talkAccent ?? this.talkAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassIcon: glassIcon ?? this.glassIcon,
      navBarBg: navBarBg ?? this.navBarBg,
      navInactive: navInactive ?? this.navInactive,
      navActiveHighlight: navActiveHighlight ?? this.navActiveHighlight,
      brandGradientStart: brandGradientStart ?? this.brandGradientStart,
      brandGradientEnd: brandGradientEnd ?? this.brandGradientEnd,
      modalSurface: modalSurface ?? this.modalSurface,
      modalBorder: modalBorder ?? this.modalBorder,
      micSelectedRing: micSelectedRing ?? this.micSelectedRing,
      segmentActive: segmentActive ?? this.segmentActive,
      taskSheetGradient: taskSheetGradient ?? this.taskSheetGradient,
      taskCardBg: taskCardBg ?? this.taskCardBg,
      toolAccentNotes: toolAccentNotes ?? this.toolAccentNotes,
      toolAccentPomodoro: toolAccentPomodoro ?? this.toolAccentPomodoro,
      footerToolsFill: footerToolsFill ?? this.footerToolsFill,
      footerToolsBorder: footerToolsBorder ?? this.footerToolsBorder,
      loginPanelFill: loginPanelFill ?? this.loginPanelFill,
      loginPanelBorder: loginPanelBorder ?? this.loginPanelBorder,
      loginGlow: loginGlow ?? this.loginGlow,
      loginLogoGradient: loginLogoGradient ?? this.loginLogoGradient,
      loginLogoShadow: loginLogoShadow ?? this.loginLogoShadow,
      navShadow: navShadow ?? this.navShadow,
    );
  }

  @override
  BubblePlannerColors lerp(ThemeExtension<BubblePlannerColors>? other, double t) {
    if (other is! BubblePlannerColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension BubblePlannerThemeContext on BuildContext {
  BubblePlannerColors get bp => BubblePlannerColors.of(this);
}

/// Старые константы — для совместимости; в UI предпочтительно [BubblePlannerColors.of].
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

  static ThemeData forPalette(AppFontChoice font, BubblePlannerColors palette) {
    final base = palette.brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = _textTheme(base.textTheme, font, palette);
    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      onSecondary: palette.onPrimary,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      error: const Color(0xFFFF6969),
      onError: Colors.white,
    );
    return base.copyWith(
      scaffoldBackgroundColor: palette.scaffold,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.brightness == Brightness.dark
            ? const Color(0xFF172031)
            : palette.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }

  /// @deprecated Используйте [forPalette] с [BubblePlannerColors.classic].
  static ThemeData dark(AppFontChoice choice) {
    return forPalette(choice, BubblePlannerColors.classic);
  }

  static TextTheme _textTheme(TextTheme base, AppFontChoice choice, BubblePlannerColors p) {
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
      AppFontChoice.dancingScript => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.dancingScript(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w600,
              height: 1.25,
            ),
      AppFontChoice.caveat => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.caveat(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w600,
              height: 1.25,
            ),
      AppFontChoice.kalam => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.kalam(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w400,
              height: 1.25,
            ),
      AppFontChoice.pacifico => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.pacifico(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w400,
              height: 1.25,
            ),
      AppFontChoice.rubik => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.rubik(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w500,
              height: 1.25,
            ),
      AppFontChoice.spaceGrotesk => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.spaceGrotesk(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w500,
              height: 1.25,
            ),
      AppFontChoice.outfit => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w500,
              height: 1.25,
            ),
      AppFontChoice.nunito => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w600,
              height: 1.25,
            ),
      AppFontChoice.playfairDisplay => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.playfairDisplay(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w600,
              height: 1.25,
            ),
      AppFontChoice.merriweather => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.merriweather(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w400,
              height: 1.25,
            ),
      AppFontChoice.inter => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w500,
              height: 1.25,
            ),
      AppFontChoice.manrope => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.manrope(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w600,
              height: 1.25,
            ),
      AppFontChoice.sora => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.sora(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w600,
              height: 1.25,
            ),
      AppFontChoice.ibmPlexSans => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.ibmPlexSans(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w500,
              height: 1.25,
            ),
      AppFontChoice.firaSans => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.firaSans(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w500,
              height: 1.25,
            ),
      AppFontChoice.josefinSans => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.josefinSans(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w600,
              height: 1.25,
            ),
      AppFontChoice.bebasNeue => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.bebasNeue(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w400,
              height: 1.25,
            ),
      AppFontChoice.libreBaskerville => ({
          double? fontSize,
          FontWeight? fontWeight,
        }) =>
            GoogleFonts.libreBaskerville(
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w400,
              height: 1.25,
            ),
    };

    return TextTheme(
      displayLarge: family(fontSize: base.displayLarge?.fontSize ?? 57, fontWeight: FontWeight.w400)
          .copyWith(color: p.textPrimary),
      displayMedium: family(fontSize: base.displayMedium?.fontSize ?? 45, fontWeight: FontWeight.w400)
          .copyWith(color: p.textPrimary),
      displaySmall: family(fontSize: base.displaySmall?.fontSize ?? 36, fontWeight: FontWeight.w400)
          .copyWith(color: p.textPrimary),
      headlineLarge: family(fontSize: base.headlineLarge?.fontSize ?? 32, fontWeight: FontWeight.w600)
          .copyWith(color: p.textPrimary),
      headlineMedium: family(fontSize: base.headlineMedium?.fontSize ?? 28, fontWeight: FontWeight.w600)
          .copyWith(color: p.textPrimary),
      headlineSmall: family(fontSize: base.headlineSmall?.fontSize ?? 24, fontWeight: FontWeight.w600)
          .copyWith(color: p.textPrimary),
      titleLarge: family(fontSize: base.titleLarge?.fontSize ?? 22, fontWeight: FontWeight.w600)
          .copyWith(color: p.textPrimary),
      titleMedium: family(fontSize: base.titleMedium?.fontSize ?? 16, fontWeight: FontWeight.w600)
          .copyWith(color: p.textPrimary),
      titleSmall: family(fontSize: base.titleSmall?.fontSize ?? 14, fontWeight: FontWeight.w600)
          .copyWith(color: p.textPrimary),
      bodyLarge: family(fontSize: base.bodyLarge?.fontSize ?? 16).copyWith(color: p.textPrimary),
      bodyMedium: family(fontSize: base.bodyMedium?.fontSize ?? 14).copyWith(color: p.textPrimary),
      bodySmall: family(fontSize: base.bodySmall?.fontSize ?? 12).copyWith(color: p.textSecondary),
      labelLarge: family(fontSize: base.labelLarge?.fontSize ?? 14, fontWeight: FontWeight.w500)
          .copyWith(color: p.textPrimary),
      labelMedium: family(fontSize: base.labelMedium?.fontSize ?? 12, fontWeight: FontWeight.w500)
          .copyWith(color: p.textSecondary),
      labelSmall: family(fontSize: base.labelSmall?.fontSize ?? 11, fontWeight: FontWeight.w500)
          .copyWith(color: p.textSecondary),
    );
  }
}
