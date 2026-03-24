/// Упрощённый порт translations.js для Flutter.
///
/// Полный файл из artifact.json очень большой, поэтому здесь
/// вынесены ключи, которые уже используются в интерфейсе,
/// и структура легко расширяется.

const Map<String, Map<String, String>> _translations = {
  'en': {
    'talk': 'Talk',
    'bubbles': 'Bubbles',
    'list': 'List',
    'share': 'Share',
    'done': 'Done',
    'pending': 'Active',
    'searchPlaceholder': 'Search tasks or categories...',
    'noTasks': 'No tasks yet',
    'bubblesFloating': 'Your bubbles will float here',
    'shareTasks': 'Shared tasks',
    'due': 'Due',
    'cancel': 'Cancel',
    'delete': 'Delete',
  },
  'ru': {
    'talk': 'Голос',
    'bubbles': 'Пузыри',
    'list': 'Список',
    'share': 'Поделиться',
    'done': 'Готово',
    'pending': 'Активные',
    'searchPlaceholder': 'Искать задачи или категории...',
    'noTasks': 'Пока нет задач',
    'bubblesFloating': 'Здесь будут плавать твои пузыри',
    'shareTasks': 'Задачи для поделиться',
    'due': 'Срок',
    'cancel': 'Отмена',
    'delete': 'Удалить',
  },
};

/// Текущий язык по умолчанию.
String currentLanguageCode = 'ru';

/// Получить перевод по ключу.
String tr(String key, {String? lang}) {
  final code = lang ?? currentLanguageCode;
  final langMap = _translations[code] ?? _translations['en']!;
  return langMap[key] ?? _translations['en']![key] ?? key;
}

