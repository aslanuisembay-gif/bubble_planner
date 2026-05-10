import '../translations.dart';

/// Человекочитаемый текст для snackbar при ошибке speech_to_text.
String voiceInputErrorSnackText(String? errorMsg, String lang) {
  final raw = errorMsg ?? '';
  final e = raw.toLowerCase();
  if (e.contains('not allowed') ||
      e.contains('permission') ||
      e.contains('denied')) {
    return tr('voiceErrorNotAllowed', lang: lang);
  }
  return trFill('voiceErrorGeneric', {'msg': raw}, lang: lang);
}
