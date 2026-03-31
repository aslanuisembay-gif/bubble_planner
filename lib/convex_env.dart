/// Конфигурация URL для Convex через `--dart-define`.
///
/// Поддерживаются 2 режима:
/// - **Простой**: один URL
///   - `--dart-define=CONVEX_URL=https://....convex.cloud`
///
/// - **Dev/Prod**: выбираем окружение и разные URL
///   - `--dart-define=ENV=dev --dart-define=CONVEX_URL_DEV=https://....convex.cloud`
///   - `--dart-define=ENV=prod --dart-define=CONVEX_URL_PROD=https://....convex.cloud`
///
/// Приоритет выбора URL:
/// 1) ENV=prod → CONVEX_URL_PROD
/// 2) ENV=dev  → CONVEX_URL_DEV
/// 3) CONVEX_URL (fallback)
class ConvexEnv {
  ConvexEnv._();

  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  static const String devUrl = String.fromEnvironment(
    'CONVEX_URL_DEV',
    defaultValue: '',
  );

  static const String prodUrl = String.fromEnvironment(
    'CONVEX_URL_PROD',
    defaultValue: '',
  );

  /// Back-compat: если не используем ENV/DEV/PROD, можно передать один URL.
  static const String fallbackUrl = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: '',
  );

  static String get deploymentUrl {
    final e = env.trim().toLowerCase();
    if (e == 'prod' && prodUrl.isNotEmpty) return prodUrl;
    if (e == 'dev' && devUrl.isNotEmpty) return devUrl;
    return fallbackUrl;
  }

  static bool get isConfigured => deploymentUrl.isNotEmpty;

  /// `true` только после успешного [ConvexClient.initialize] в [main].
  static bool backendReady = false;
}
