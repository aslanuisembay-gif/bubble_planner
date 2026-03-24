import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'task_parser.dart';

enum AppFontChoice { systemDefault, pressStart2p, specialElite, cinzel }

enum SettingsTab { appearance, routines, language }

class BubbleCategory {
  const BubbleCategory({
    required this.id,
    required this.title,
    required this.tasksCount,
    required this.color,
    required this.position,
    required this.size,
  });

  final String id;
  final String title;
  final int tasksCount;
  final Color color;
  final Offset position;
  final double size;

  BubbleCategory copyWith({
    String? id,
    String? title,
    int? tasksCount,
    Color? color,
    Offset? position,
    double? size,
  }) {
    return BubbleCategory(
      id: id ?? this.id,
      title: title ?? this.title,
      tasksCount: tasksCount ?? this.tasksCount,
      color: color ?? this.color,
      position: position ?? this.position,
      size: size ?? this.size,
    );
  }
}

class RoutineItem {
  RoutineItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.timeRange,
  });

  final String id;
  final IconData icon;
  final String title;
  final String timeRange;
}

class BubbleTaskItem {
  BubbleTaskItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.dueAt,
    this.isDone = false,
  });

  final String id;
  final String categoryId;
  final String title;
  final DateTime dueAt;
  final bool isDone;

  BubbleTaskItem copyWith({
    String? id,
    String? categoryId,
    String? title,
    DateTime? dueAt,
    bool? isDone,
  }) {
    return BubbleTaskItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      dueAt: dueAt ?? this.dueAt,
      isDone: isDone ?? this.isDone,
    );
  }
}

class AppState extends ChangeNotifier {
  AppFontChoice _fontChoice = AppFontChoice.systemDefault;
  bool _dailyRoutinesEnabled = true;
  bool _voiceActivationEnabled = false;
  SettingsTab _activeSettingsTab = SettingsTab.appearance;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  int _idSeed = 100;

  final List<BubbleCategory> _categories = [
    BubbleCategory(
      id: 'kids',
      title: 'Kids',
      tasksCount: 3,
      color: Color(0xFFFFB36A),
      position: Offset(0.18, 0.24),
      size: 154,
    ),
    BubbleCategory(
      id: 'work',
      title: 'Work',
      tasksCount: 2,
      color: Color(0xFF67A9FF),
      position: Offset(0.77, 0.27),
      size: 132,
    ),
    BubbleCategory(
      id: 'shopping',
      title: 'Shopping',
      tasksCount: 2,
      color: Color(0xFFB88BFF),
      position: Offset(0.35, 0.53),
      size: 144,
    ),
    BubbleCategory(
      id: 'health',
      title: 'Health',
      tasksCount: 2,
      color: Color(0xFF65DEA3),
      position: Offset(0.72, 0.62),
      size: 126,
    ),
    BubbleCategory(
      id: 'rabota',
      title: 'Работа',
      tasksCount: 1,
      color: Color(0xFFFF8D8D),
      position: Offset(0.16, 0.73),
      size: 116,
    ),
  ];

  final List<RoutineItem> _routines = [
    RoutineItem(
      id: 'morning',
      icon: Icons.wb_sunny_rounded,
      title: 'Morning Focus',
      timeRange: '07:00 - 09:00',
    ),
    RoutineItem(
      id: 'work',
      icon: Icons.work_outline_rounded,
      title: 'Deep Work',
      timeRange: '10:00 - 13:00',
    ),
    RoutineItem(
      id: 'evening',
      icon: Icons.nights_stay_outlined,
      title: 'Evening Wind Down',
      timeRange: '20:00 - 22:00',
    ),
  ];
  final List<BubbleTaskItem> _tasks = [
    BubbleTaskItem(
      id: 't1',
      categoryId: 'work',
      title: 'CONFIRM DESIGN MEETING',
      dueAt: DateTime(2026, 3, 1, 20, 1),
    ),
    BubbleTaskItem(
      id: 't2',
      categoryId: 'work',
      title: 'GJHFUIH',
      dueAt: DateTime(2026, 3, 2, 23, 33),
    ),
    BubbleTaskItem(
      id: 't3',
      categoryId: 'kids',
      title: 'PICK UP FROM SCHOOL',
      dueAt: DateTime(2026, 3, 2, 18, 0),
    ),
    BubbleTaskItem(
      id: 't4',
      categoryId: 'shopping',
      title: 'BUY MILK AND BREAD',
      dueAt: DateTime(2026, 3, 3, 19, 15),
    ),
    BubbleTaskItem(
      id: 't5',
      categoryId: 'health',
      title: 'BOOK DOCTOR APPOINTMENT',
      dueAt: DateTime(2026, 3, 4, 10, 0),
    ),
    BubbleTaskItem(
      id: 't6',
      categoryId: 'rabota',
      title: 'ОТПРАВИТЬ ОТЧЕТ',
      dueAt: DateTime(2026, 3, 3, 16, 45),
    ),
  ];

  AppFontChoice get fontChoice => _fontChoice;
  bool get dailyRoutinesEnabled => _dailyRoutinesEnabled;
  bool get voiceActivationEnabled => _voiceActivationEnabled;
  SettingsTab get activeSettingsTab => _activeSettingsTab;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  List<BubbleCategory> get categories => _categories;
  List<RoutineItem> get routines => List.unmodifiable(_routines);
  List<BubbleTaskItem> get tasks => List.unmodifiable(_tasks);

  int get doneCount => _tasks.where((t) => t.isDone).length;
  int get activeCount => _tasks.where((t) => !t.isDone).length;

  void setFontChoice(AppFontChoice choice) {
    _fontChoice = choice;
    notifyListeners();
  }

  void setActiveSettingsTab(SettingsTab tab) {
    _activeSettingsTab = tab;
    notifyListeners();
  }

  void toggleDailyRoutines(bool value) {
    _dailyRoutinesEnabled = value;
    notifyListeners();
  }

  void toggleVoiceActivation(bool value) {
    _voiceActivationEnabled = value;
    notifyListeners();
  }

  void removeRoutine(String id) {
    _routines.removeWhere((element) => element.id == id);
    notifyListeners();
  }

  Future<void> syncHub() async {
    _isSyncing = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _isSyncing = false;
    _lastSyncedAt = DateTime.now();
    notifyListeners();
  }

  void addTaskFromText(String rawText) {
    final parsed = parseTask(rawText);
    final categoryId = _categoryIdByParsedCategory(parsed.category);
    _idSeed += 1;
    _tasks.add(
      BubbleTaskItem(
        id: 't$_idSeed',
        categoryId: categoryId,
        title: parsed.text.toUpperCase(),
        dueAt: parsed.dueAt ?? DateTime.now().add(const Duration(hours: 4)),
      ),
    );
    _recomputeCategoryCounts();
    notifyListeners();
  }

  List<BubbleTaskItem> tasksByCategory(String categoryId) {
    final result = _tasks.where((t) => t.categoryId == categoryId).toList();
    result.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return result;
  }

  void toggleTaskDone(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final item = _tasks[index];
    _tasks[index] = item.copyWith(isDone: !item.isDone);
    notifyListeners();
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    _recomputeCategoryCounts();
    notifyListeners();
  }

  void _recomputeCategoryCounts() {
    for (var i = 0; i < _categories.length; i++) {
      final category = _categories[i];
      final count = _tasks.where((t) => t.categoryId == category.id && !t.isDone).length;
      _categories[i] = category.copyWith(tasksCount: count);
    }
  }

  String formatDueTime(DateTime dueAt) => DateFormat('HH:mm').format(dueAt);

  String formatDueDay(DateTime dueAt) {
    const months = [
      'янв',
      'фев',
      'март',
      'апр',
      'май',
      'июнь',
      'июль',
      'авг',
      'сент',
      'окт',
      'нояб',
      'дек',
    ];
    return '${dueAt.day} ${months[dueAt.month - 1]}';
  }

  String _categoryIdByParsedCategory(String category) {
    switch (category) {
      case 'Дети':
        return 'kids';
      case 'Работа':
        return 'work';
      case 'Покупки':
        return 'shopping';
      case 'Здоровье':
        return 'health';
      default:
        return 'rabota';
    }
  }
}

double bubbleFloatDurationMs(String categoryId) {
  final seed = categoryId.hashCode.abs();
  return (4800 + Random(seed).nextInt(2400)).toDouble();
}
