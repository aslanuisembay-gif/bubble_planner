import 'package:intl/intl.dart';

/// Категории задач, портированные из taskParser.js.
///
/// В оригинале используются регулярки по подстрокам; здесь мы
/// повторяем эту логику с помощью [RegExp].
class TaskCategory {
  const TaskCategory(this.name, this.pattern);

  final String name;
  final RegExp pattern;
}

final List<TaskCategory> kCategories = [
  TaskCategory(
    'Покупки',
    RegExp(
      r'куп|магаз|маркет|вкусвилл|еда|молоко|хлеб|buy|shop|grocery',
      caseSensitive: false,
    ),
  ),
  TaskCategory(
    'Работа',
    RegExp(
      r'раб|мит|звон|почт|встреч|колл|тикет|work|job|meet|call|email',
      caseSensitive: false,
    ),
  ),
  TaskCategory(
    'Дом',
    RegExp(
      r'дом|убор|посуд|стир|ремонт|home|house|clean|fix',
      caseSensitive: false,
    ),
  ),
  TaskCategory(
    'Здоровье',
    RegExp(
      r'врач|здор|аптек|таблет|спорт|зал|тренир|запись|прием|doctor|health|gym|sport|appointment|appoint|visit|кездесу',
      caseSensitive: false,
    ),
  ),
  TaskCategory(
    'Дети',
    RegExp(
      r'дет|ребен|сад|школ|урок|kids|child|school|lesson',
      caseSensitive: false,
    ),
  ),
  TaskCategory(
    'Финансы',
    RegExp(
      r'ден|банк|оплат|счет|карт|money|bank|pay|bill',
      caseSensitive: false,
    ),
  ),
  TaskCategory(
    'Общее',
    RegExp(r'.*', caseSensitive: false),
  ),
];

/// Результат парсинга текстовой команды в задачу.
class ParsedTask {
  ParsedTask({
    required this.text,
    required this.category,
    this.dueAt,
  });

  final String text;
  final String category;
  final DateTime? dueAt;
}

/// Упрощённый порт parseTask(text) из JS‑версии.
///
/// Сейчас:
/// - определяет категорию по ключевым словам;
/// - пытается вытащить дедлайн в формате «сегодня/завтра HH:MM» или просто «HH:MM»;
/// - возвращает очищенный текст задачи.
ParsedTask parseTask(String raw) {
  final text = raw.trim();
  final lower = text.toLowerCase();

  // 1) Категория.
  String category = 'Общее';
  for (final cat in kCategories) {
    if (cat.name == 'Общее') continue;
    if (cat.pattern.hasMatch(lower)) {
      category = cat.name;
      break;
    }
  }

  // 2) Поиск времени вида 20:01 / 8:30 и слов "today/сегодня", "tomorrow/завтра".
  final timeRegex = RegExp(r'\b(\d{1,2}):(\d{2})\b');
  final match = timeRegex.firstMatch(lower);
  DateTime? dueAt;

  if (match != null) {
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour != null && minute != null) {
      final now = DateTime.now();
      var baseDate = DateTime(now.year, now.month, now.day);

      if (lower.contains('завтра') || lower.contains('tomorrow')) {
        baseDate = baseDate.add(const Duration(days: 1));
      }

      dueAt = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
    }
  }

  // 3) Немного чистим текст вывода: убираем лишние пробелы.
  final cleanText = _normalizeSpaces(text);

  return ParsedTask(
    text: cleanText,
    category: category,
    dueAt: dueAt,
  );
}

String _normalizeSpaces(String input) {
  return input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Форматирование dueAt в стиле LIST/Bubbles (dd MMM, HH:mm).
String formatDueShort(DateTime? dueAt) {
  if (dueAt == null) return '';
  final time = DateFormat('HH:mm').format(dueAt);
  final date = DateFormat('d MMM').format(dueAt);
  return '$time · $date';
}

