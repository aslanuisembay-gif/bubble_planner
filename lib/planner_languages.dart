/// Поддерживаемые коды интерфейса (15 языков; полные строки — en/ru/kk, остальные → en).
const List<String> kPlannerLanguageCodes = [
  'en',
  'ru',
  'kk',
  'de',
  'fr',
  'es',
  'zh',
  'ja',
  'ko',
  'ar',
  'tr',
  'uk',
  'pl',
  'it',
  'hi',
];

bool isPlannerLanguageCode(String code) => kPlannerLanguageCodes.contains(code);

/// Название языка на нём самом (для списка в настройках).
String plannerLanguageNativeLabel(String code) {
  switch (code) {
    case 'en':
      return 'English';
    case 'ru':
      return 'Русский';
    case 'kk':
      return 'Қазақша';
    case 'de':
      return 'Deutsch';
    case 'fr':
      return 'Français';
    case 'es':
      return 'Español';
    case 'zh':
      return '中文';
    case 'ja':
      return '日本語';
    case 'ko':
      return '한국어';
    case 'ar':
      return 'العربية';
    case 'tr':
      return 'Türkçe';
    case 'uk':
      return 'Українська';
    case 'pl':
      return 'Polski';
    case 'it':
      return 'Italiano';
    case 'hi':
      return 'हिन्दी';
    default:
      return code;
  }
}
