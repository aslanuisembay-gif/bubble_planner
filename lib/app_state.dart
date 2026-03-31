import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'convex_auth_session.dart';
import 'local_tasks_sync.dart';
import 'convex_env.dart';
import 'task_parser.dart';

/// Sentinel for [BubbleTaskItem.copyWith] when `null` should mean "clear field".
const Object _kTaskCopyUnset = Object();

enum AppFontChoice { systemDefault, pressStart2p, specialElite, cinzel }

enum SettingsTab { appearance, routines, language }

enum TaskListFilter { all, active, done }

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
    required this.categoryTag,
    required this.title,
    required this.dueAt,
    this.isDone = false,
    this.recurrenceDays,
    this.reminderAt,
  });

  final String id;
  final String categoryId;
  final String categoryTag;
  final String title;
  final DateTime dueAt;
  final bool isDone;
  final List<String>? recurrenceDays;
  /// Optional reminder (full date+time). Shown in list when set.
  final DateTime? reminderAt;

  BubbleTaskItem copyWith({
    String? id,
    String? categoryId,
    String? categoryTag,
    String? title,
    DateTime? dueAt,
    bool? isDone,
    Object? recurrenceDays = _kTaskCopyUnset,
    Object? reminderAt = _kTaskCopyUnset,
  }) {
    return BubbleTaskItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryTag: categoryTag ?? this.categoryTag,
      title: title ?? this.title,
      dueAt: dueAt ?? this.dueAt,
      isDone: isDone ?? this.isDone,
      recurrenceDays: identical(recurrenceDays, _kTaskCopyUnset)
          ? this.recurrenceDays
          : recurrenceDays as List<String>?,
      reminderAt: identical(reminderAt, _kTaskCopyUnset)
          ? this.reminderAt
          : reminderAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'categoryTag': categoryTag,
        'title': title,
        'dueAtMs': dueAt.millisecondsSinceEpoch,
        'isDone': isDone,
        if (recurrenceDays != null) 'recurrenceDays': recurrenceDays,
        if (reminderAt != null) 'reminderAtMs': reminderAt!.millisecondsSinceEpoch,
      };

  factory BubbleTaskItem.fromJson(Map<String, dynamic> m) {
    List<String>? rd;
    final r = m['recurrenceDays'];
    if (r is List) {
      rd = r.map((e) => e.toString()).toList();
    }
    final rem = m['reminderAtMs'];
    final dueRaw = m['dueAtMs'];
    final dueMs = dueRaw is num ? dueRaw.toInt() : int.parse('$dueRaw');
    return BubbleTaskItem(
      id: '${m['id']}',
      categoryId: '${m['categoryId']}',
      categoryTag: '${m['categoryTag']}',
      title: '${m['title']}',
      dueAt: DateTime.fromMillisecondsSinceEpoch(dueMs),
      isDone: m['isDone'] as bool? ?? false,
      recurrenceDays: rd,
      reminderAt: rem == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              rem is num ? rem.toInt() : int.parse('$rem'),
            ),
    );
  }
}

class AppState extends ChangeNotifier {
  AppState() {
    _recomputeCategoryCounts();
    unawaited(_bootstrapSession());
  }

  Future<void> _bootstrapSession() async {
    if (!ConvexEnv.isConfigured || !ConvexEnv.backendReady) {
      return;
    }
    try {
      final restored = await ConvexAuthSession.tryRestore();
      // Пользователь уже выбрал локальный demo (флаг выставлен до await в tryLogin).
      if (_localDemoSession) {
        return;
      }
      if (!restored) {
        return;
      }
      final raw = await ConvexClient.instance.query('auth:isAuthenticated', {});
      if (_localDemoSession) {
        return;
      }
      final isAuth = jsonDecode(raw) == true;
      if (!isAuth) {
        return;
      }
      if (_localDemoSession) {
        return;
      }
      _convexLoading = true;
      notifyListeners();
      _isLoggedIn = true;
      _localDemoSession = false;
      notifyListeners();
      await _convexSeedDemoIfNeeded();
      if (_localDemoSession) {
        _stopConvexSync();
        return;
      }
      await _convexSubscribeTasks();
    } catch (e, st) {
      debugPrint('_bootstrapSession: $e\n$st');
    } finally {
      _convexLoading = false;
      _recomputeCategoryCounts();
      notifyListeners();
    }
  }

  AppFontChoice _fontChoice = AppFontChoice.systemDefault;
  bool _dailyRoutinesEnabled = true;
  bool _voiceActivationEnabled = false;
  SettingsTab _activeSettingsTab = SettingsTab.appearance;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  int _idSeed = 200;

  bool _isLoggedIn = false;
  /// Локальные демо-задачи (demo/demo), без Convex API.
  bool _localDemoSession = false;
  TaskListFilter _listFilter = TaskListFilter.all;
  String _searchQuery = '';
  final Set<String> _selectedTaskIds = {};

  bool _convexLoading = false;
  String? _convexError;
  void Function()? _cancelTasksSub;

  static const String _kPrefsLocalTasks = 'bubble_planner_local_tasks_v1';
  static const String _kPrefsLocalIdSeed = 'bubble_planner_local_id_seed_v1';

  final List<BubbleCategory> _categories = [
    const BubbleCategory(
      id: 'kids',
      title: 'Kids',
      tasksCount: 0,
      color: Color(0xFFFFB36A),
      position: Offset(0.18, 0.24),
      size: 154,
    ),
    const BubbleCategory(
      id: 'work',
      title: 'Work',
      tasksCount: 0,
      color: Color(0xFF67A9FF),
      position: Offset(0.77, 0.27),
      size: 132,
    ),
    const BubbleCategory(
      id: 'shopping',
      title: 'Shopping',
      tasksCount: 0,
      color: Color(0xFFB88BFF),
      position: Offset(0.35, 0.53),
      size: 144,
    ),
    const BubbleCategory(
      id: 'health',
      title: 'Health',
      tasksCount: 0,
      color: Color(0xFF65DEA3),
      position: Offset(0.72, 0.62),
      size: 126,
    ),
    const BubbleCategory(
      id: 'general',
      title: 'General',
      tasksCount: 0,
      color: Color(0xFF9CA3AF),
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

  final List<BubbleTaskItem> _tasks = [];

  AppFontChoice get fontChoice => _fontChoice;
  bool get dailyRoutinesEnabled => _dailyRoutinesEnabled;
  bool get voiceActivationEnabled => _voiceActivationEnabled;
  SettingsTab get activeSettingsTab => _activeSettingsTab;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  List<BubbleCategory> get categories => _categories;
  List<RoutineItem> get routines => List.unmodifiable(_routines);
  List<BubbleTaskItem> get tasks => List.unmodifiable(_tasks);
  bool get isLoggedIn => _isLoggedIn;
  TaskListFilter get listFilter => _listFilter;
  String get searchQuery => _searchQuery;
  Set<String> get selectedTaskIds => Set.unmodifiable(_selectedTaskIds);
  bool get isSelectionMode => _selectedTaskIds.isNotEmpty;

  bool get convexLoading => _convexLoading;
  String? get convexError => _convexError;

  /// Convex + JWT: задачи в облаке с проверкой на сервере ([getAuthUserId]).
  bool get useConvexBackend =>
      ConvexEnv.isConfigured &&
      ConvexEnv.backendReady &&
      _isLoggedIn &&
      !_localDemoSession;

  bool get _useConvex => useConvexBackend;

  int get doneCount => _tasks.where((t) => t.isDone).length;
  int get activeCount => _tasks.where((t) => !t.isDone).length;

  static DateTime get _demoToday {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _seedDemoTasks() {
    final t0 = _demoToday;
    _tasks
      ..clear()
      ..addAll([
        BubbleTaskItem(
          id: 't1',
          categoryId: 'health',
          categoryTag: 'HEALTH',
          title: 'BUY VITAMINS',
          dueAt: t0.add(const Duration(hours: 12)),
          isDone: true,
        ),
        BubbleTaskItem(
          id: 't2',
          categoryId: 'work',
          categoryTag: 'WORK',
          title: 'CONFIRM DESIGN MEETING',
          dueAt: t0.add(const Duration(hours: 21, minutes: 34)),
        ),
        BubbleTaskItem(
          id: 't3',
          categoryId: 'general',
          categoryTag: 'GENERAL',
          title: 'GFHGGJJKHHJ',
          dueAt: t0.add(const Duration(hours: 23, minutes: 45)),
        ),
        BubbleTaskItem(
          id: 't4',
          categoryId: 'general',
          categoryTag: 'GENERAL',
          title: 'TRAIN THE MARSH BEFORE HIS PLAYOFF HOCKEY GAMES',
          dueAt: () {
            final d = t0.add(const Duration(days: 1));
            return DateTime(d.year, d.month, d.day, 20, 34);
          }(),
          recurrenceDays: const ['Пн', 'Ср', 'Пт'],
        ),
        BubbleTaskItem(
          id: 't5',
          categoryId: 'shopping',
          categoryTag: 'SHOPPING',
          title: 'PICK UP PARCEL FROM PIATYOROCHKA',
          dueAt: () {
            final d = t0.add(const Duration(days: 1));
            return DateTime(d.year, d.month, d.day, 20, 34);
          }(),
        ),
        BubbleTaskItem(
          id: 't6',
          categoryId: 'shopping',
          categoryTag: 'SHOPPING',
          title: 'BUY SOME GROCERIES',
          dueAt: t0.add(const Duration(hours: 20, minutes: 31)),
        ),
      ]);
  }

  void _touchLocalTasks() {
    if (_isLoggedIn && !useConvexBackend) {
      unawaited(persistLocalTasksNow());
    }
  }

  /// Сохранить локальные задачи (demo / без Convex). Ждать при уходе с вкладки и т.п.
  Future<void> persistLocalTasksNow() async {
    if (!_isLoggedIn || useConvexBackend) {
      return;
    }
    await _saveLocalTasksToDisk();
  }

  Future<void> _saveLocalTasksToDisk() async {
    try {
      final payload = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      if (kIsWeb) {
        // Синхронно в localStorage с тем же ключом, что shared_preferences_web (flutter.*).
        // Иначе при смене порта / закрытии вкладки async-запись не успевает.
        writeLocalTasksSync(payload, _idSeed);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsLocalTasks, payload);
      await prefs.setInt(_kPrefsLocalIdSeed, _idSeed);
    } catch (e, st) {
      debugPrint('_saveLocalTasksToDisk: $e\n$st');
    }
  }

  Future<void> _restoreLocalTasksOrSeedDemo() async {
    try {
      String? raw;
      int? seedFromStore;
      if (kIsWeb) {
        final r = readLocalTasksSync();
        raw = r.$1;
        seedFromStore = r.$2;
      } else {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_kPrefsLocalTasks);
        seedFromStore = prefs.getInt(_kPrefsLocalIdSeed);
      }
      if (raw == null || raw.isEmpty) {
        _seedDemoTasks();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) {
        _seedDemoTasks();
        return;
      }
      _tasks.clear();
      for (final e in decoded) {
        if (e is! Map) {
          continue;
        }
        _tasks.add(
          BubbleTaskItem.fromJson(
            e.map((k, v) => MapEntry('$k', v)),
          ),
        );
      }
      if (_tasks.isEmpty) {
        _seedDemoTasks();
        return;
      }
      if (seedFromStore != null && seedFromStore >= _idSeed) {
        _idSeed = seedFromStore;
      }
    } catch (e, st) {
      debugPrint('_restoreLocalTasksOrSeedDemo: $e\n$st');
      _seedDemoTasks();
    }
  }

  Future<bool> tryLogin(
    String user,
    String password, {
    bool signUp = false,
  }) async {
    _selectedTaskIds.clear();
    _convexError = null;

    final u = user.trim();
    if (u == 'demo' && password == 'demo') {
      // Сразу, до любых await — иначе _bootstrapSession успевает подписаться на Convex и затирает _tasks.
      _localDemoSession = true;
      _stopConvexSync();
      if (ConvexEnv.isConfigured && ConvexEnv.backendReady) {
        unawaited(ConvexAuthSession.signOut());
      }
      _isLoggedIn = true;
      await _restoreLocalTasksOrSeedDemo();
      _recomputeCategoryCounts();
      await persistLocalTasksNow();
      notifyListeners();
      return true;
    }

    if (!ConvexEnv.isConfigured || !ConvexEnv.backendReady) {
      return false;
    }

    _localDemoSession = false;
    _convexLoading = true;
    notifyListeners();
    try {
      await ConvexAuthSession.signIn(
        email: u,
        password: password,
        signUp: signUp,
      );
      _isLoggedIn = true;
      notifyListeners();
      await _convexSeedDemoIfNeeded();
      await _convexSubscribeTasks();
      return true;
    } catch (e, st) {
      debugPrint('Convex login failed: $e\n$st');
      _convexError = _formatConvexError(e);
      return false;
    } finally {
      _convexLoading = false;
      _recomputeCategoryCounts();
      notifyListeners();
    }
  }

  String _formatConvexError(Object e) {
    var s = e.toString();
    s = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
    s = s.replaceFirst(RegExp(r'^.*Server Error\s*'), '');
    if (s.length > 280) {
      s = '${s.substring(0, 280)}…';
    }
    return s.trim();
  }

  void logout() {
    _stopConvexSync();
    if (ConvexEnv.isConfigured && ConvexEnv.backendReady) {
      unawaited(ConvexAuthSession.signOut());
    }
    _isLoggedIn = false;
    _localDemoSession = false;
    _convexError = null;
    _tasks.clear();
    _selectedTaskIds.clear();
    _recomputeCategoryCounts();
    notifyListeners();
  }

  void _stopConvexSync() {
    _cancelTasksSub?.call();
    _cancelTasksSub = null;
  }

  Future<void> _convexSeedDemoIfNeeded() async {
    await ConvexClient.instance.mutation(
      name: 'tasks:seedDemoForUser',
      args: {},
    );
  }

  Future<void> _convexSubscribeTasks() async {
    _stopConvexSync();
    final handle = await ConvexClient.instance.subscribe(
      name: 'tasks:listForUser',
      args: {},
      onUpdate: (json) {
        try {
          final next = _parseTasksFromConvexJson(json);
          _tasks
            ..clear()
            ..addAll(next);
          _recomputeCategoryCounts();
          notifyListeners();
        } catch (e, st) {
          debugPrint('Convex list parse: $e\n$st');
        }
      },
      onError: (message, value) {
        debugPrint('Convex subscription error: $message value=$value');
      },
    );
    _cancelTasksSub = () {
      handle.cancel();
      _cancelTasksSub = null;
    };
  }

  List<BubbleTaskItem> _parseTasksFromConvexJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['_id']?.toString() ?? '';
      final recurrence = m['recurrenceDays'];
      List<String>? rd;
      if (recurrence is List) {
        rd = recurrence.map((x) => x.toString()).toList();
      }
      final rem = m['reminderAtMs'];
      DateTime? remAt;
      if (rem is num) {
        remAt = DateTime.fromMillisecondsSinceEpoch(rem.toInt());
      }
      return BubbleTaskItem(
        id: id,
        categoryId: m['categoryId'] as String,
        categoryTag: m['categoryTag'] as String,
        title: m['title'] as String,
        dueAt: DateTime.fromMillisecondsSinceEpoch(
          (m['dueAtMs'] as num).toInt(),
        ),
        isDone: m['isDone'] as bool,
        recurrenceDays: rd,
        reminderAt: remAt,
      );
    }).toList();
  }

  @override
  void dispose() {
    _stopConvexSync();
    super.dispose();
  }

  void setListFilter(TaskListFilter f) {
    _listFilter = f;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void toggleTaskSelection(String taskId) {
    if (_selectedTaskIds.contains(taskId)) {
      _selectedTaskIds.remove(taskId);
    } else {
      _selectedTaskIds.add(taskId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedTaskIds.clear();
    notifyListeners();
  }

  void selectAllVisible(Iterable<String> ids) {
    _selectedTaskIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  String shareTextForTasks(Iterable<String> ids) {
    final set = ids.toSet();
    return _tasks
        .where((t) => set.contains(t.id))
        .map((t) => t.title)
        .join('\n');
  }

  void deleteTasksByIds(Iterable<String> ids) {
    if (_useConvex) {
      final set = ids.toSet();
      _selectedTaskIds.removeWhere(set.contains);
      notifyListeners();
      unawaited(_convexRemoveMany(ids));
      return;
    }
    final set = ids.toSet();
    _tasks.removeWhere((t) => set.contains(t.id));
    _selectedTaskIds.removeWhere(set.contains);
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  Future<void> _convexRemoveMany(Iterable<String> ids) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'tasks:removeMany',
        args: {
          'ids': ids.toList(),
        },
      );
    } catch (e, st) {
      debugPrint('Convex removeMany: $e\n$st');
    }
  }

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
    if (_useConvex) {
      try {
        await ConvexClient.instance.query('health:ping', {});
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    _isSyncing = false;
    _lastSyncedAt = DateTime.now();
    notifyListeners();
  }

  void applySyncHubResults() {
    if (_useConvex) {
      unawaited(_convexAddSyncHubDemo());
      return;
    }
    final base = _demoToday;
    _idSeed += 1;
    _tasks.addAll([
      BubbleTaskItem(
        id: 'sync_${_idSeed}_1',
        categoryId: 'work',
        categoryTag: 'WORK',
        title: 'REVIEW EMAIL FROM TEAM',
        dueAt: base.add(const Duration(hours: 10)),
      ),
      BubbleTaskItem(
        id: 'sync_${_idSeed}_2',
        categoryId: 'shopping',
        categoryTag: 'SHOPPING',
        title: 'ORDER SUPPLIES FROM LIST',
        dueAt: base.add(const Duration(hours: 14)),
      ),
      BubbleTaskItem(
        id: 'sync_${_idSeed}_3',
        categoryId: 'general',
        categoryTag: 'GENERAL',
        title: 'FOLLOW UP CALENDAR INVITE',
        dueAt: base.add(const Duration(days: 1, hours: 9)),
      ),
      BubbleTaskItem(
        id: 'sync_${_idSeed}_4',
        categoryId: 'health',
        categoryTag: 'HEALTH',
        title: 'SCHEDULE CHECKUP FROM NOTE',
        dueAt: base.add(const Duration(days: 2, hours: 11)),
      ),
    ]);
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  Future<void> _convexAddSyncHubDemo() async {
    try {
      await ConvexClient.instance.mutation(
        name: 'tasks:addSyncHubDemo',
        args: {},
      );
    } catch (e, st) {
      debugPrint('Convex addSyncHubDemo: $e\n$st');
    }
  }

  void addTaskFromText(String rawText) {
    final parsed = parseTask(rawText);
    final categoryId = _categoryIdByParsedCategory(parsed.category);
    final tag = _tagFromParsedCategory(parsed.category);
    final dueAt = parsed.dueAt ?? DateTime.now().add(const Duration(hours: 2));
    if (_useConvex) {
      unawaited(
        _convexCreate(
          categoryId: categoryId,
          categoryTag: tag,
          title: parsed.text.toUpperCase(),
          dueAt: dueAt,
          isDone: false,
        ),
      );
      return;
    }
    _idSeed += 1;
    _tasks.add(
      BubbleTaskItem(
        id: 't$_idSeed',
        categoryId: categoryId,
        categoryTag: tag,
        title: parsed.text.toUpperCase(),
        dueAt: dueAt,
      ),
    );
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  void addConfirmedTask(String rawTitle, DateTime dueAt) {
    final parsed = parseTask(rawTitle);
    final categoryId = _categoryIdByParsedCategory(parsed.category);
    final tag = _tagFromParsedCategory(parsed.category);
    if (_useConvex) {
      unawaited(
        _convexCreate(
          categoryId: categoryId,
          categoryTag: tag,
          title: parsed.text.toUpperCase(),
          dueAt: dueAt,
          isDone: false,
        ),
      );
      return;
    }
    _idSeed += 1;
    _tasks.add(
      BubbleTaskItem(
        id: 't$_idSeed',
        categoryId: categoryId,
        categoryTag: tag,
        title: parsed.text.toUpperCase(),
        dueAt: dueAt,
      ),
    );
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  void addTaskWithDue({
    required String title,
    required DateTime dueAt,
    String? categoryId,
    String? categoryTag,
  }) {
    final id = categoryId ?? 'general';
    final tag = categoryTag ?? 'GENERAL';
    if (_useConvex) {
      unawaited(
        _convexCreate(
          categoryId: id,
          categoryTag: tag,
          title: title.toUpperCase(),
          dueAt: dueAt,
          isDone: false,
        ),
      );
      return;
    }
    _idSeed += 1;
    _tasks.add(
      BubbleTaskItem(
        id: 't$_idSeed',
        categoryId: id,
        categoryTag: tag,
        title: title.toUpperCase(),
        dueAt: dueAt,
      ),
    );
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  Future<void> _convexCreate({
    required String categoryId,
    required String categoryTag,
    required String title,
    required DateTime dueAt,
    required bool isDone,
    List<String>? recurrenceDays,
    DateTime? reminderAt,
  }) async {
    try {
      final args = <String, dynamic>{
        'categoryId': categoryId,
        'categoryTag': categoryTag,
        'title': title,
        'dueAtMs': dueAt.millisecondsSinceEpoch,
        'isDone': isDone,
      };
      if (recurrenceDays != null) {
        args['recurrenceDays'] = recurrenceDays;
      }
      if (reminderAt != null) {
        args['reminderAtMs'] = reminderAt.millisecondsSinceEpoch;
      }
      await ConvexClient.instance.mutation(name: 'tasks:create', args: args);
    } catch (e, st) {
      debugPrint('Convex create: $e\n$st');
    }
  }

  void updateTaskDue(String taskId, DateTime dueAt) {
    if (_useConvex) {
      unawaited(
        _convexUpdate(
          taskId,
          {'dueAtMs': dueAt.millisecondsSinceEpoch},
        ),
      );
      return;
    }
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(dueAt: dueAt);
    _touchLocalTasks();
    notifyListeners();
  }

  void updateTaskTitle(String taskId, String title) {
    if (_useConvex) {
      unawaited(_convexUpdate(taskId, {'title': title.toUpperCase()}));
      return;
    }
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(title: title.toUpperCase());
    _touchLocalTasks();
    notifyListeners();
  }

  void updateTaskRecurrence(String taskId, List<String>? recurrenceDays) {
    if (_useConvex) {
      if (recurrenceDays == null || recurrenceDays.isEmpty) {
        unawaited(
          _convexUpdate(taskId, {'clearRecurrence': true}),
        );
      } else {
        unawaited(_convexUpdate(taskId, {'recurrenceDays': recurrenceDays}));
      }
      return;
    }
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(recurrenceDays: recurrenceDays);
    _touchLocalTasks();
    notifyListeners();
  }

  void updateTaskReminder(String taskId, DateTime? reminderAt) {
    if (_useConvex) {
      if (reminderAt == null) {
        unawaited(_convexUpdate(taskId, {'clearReminder': true}));
      } else {
        unawaited(
          _convexUpdate(
            taskId,
            {'reminderAtMs': reminderAt.millisecondsSinceEpoch},
          ),
        );
      }
      return;
    }
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(reminderAt: reminderAt);
    _touchLocalTasks();
    notifyListeners();
  }

  Future<void> _convexUpdate(String taskId, Map<String, dynamic> fields) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'tasks:updateFields',
        args: {
          'id': taskId,
          ...fields,
        },
      );
    } catch (e, st) {
      debugPrint('Convex updateFields: $e\n$st');
    }
  }

  /// Cycles recurrence: none → Пн/Ср/Пт → daily abbrev → none.
  void toggleTaskRecurrencePreset(String taskId) {
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    final cur = _tasks[i].recurrenceDays;
    List<String>? next;
    bool clear = false;
    if (cur == null || cur.isEmpty) {
      next = const ['Пн', 'Ср', 'Пт'];
    } else if (cur.length == 3) {
      next = const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    } else {
      clear = true;
    }
    if (_useConvex) {
      if (clear) {
        unawaited(_convexUpdate(taskId, {'clearRecurrence': true}));
      } else {
        unawaited(_convexUpdate(taskId, {'recurrenceDays': next}));
      }
      return;
    }
    if (clear) {
      _tasks[i] = _tasks[i].copyWith(recurrenceDays: null);
    } else {
      _tasks[i] = _tasks[i].copyWith(recurrenceDays: next);
    }
    _touchLocalTasks();
    notifyListeners();
  }

  List<BubbleTaskItem> tasksForListView() {
    Iterable<BubbleTaskItem> list = _tasks;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where(
        (t) =>
            t.title.toLowerCase().contains(q) ||
            t.categoryTag.toLowerCase().contains(q),
      );
    }
    switch (_listFilter) {
      case TaskListFilter.all:
        break;
      case TaskListFilter.active:
        list = list.where((t) => !t.isDone);
        break;
      case TaskListFilter.done:
        list = list.where((t) => t.isDone);
        break;
    }
    final out = list.toList();
    out.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return out;
  }

  bool isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<BubbleTaskItem> tasksByCategory(String categoryId) {
    final result = _tasks.where((t) => t.categoryId == categoryId).toList();
    result.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return result;
  }

  void toggleTaskDone(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final item = _tasks[index];
    final next = !item.isDone;
    if (_useConvex) {
      unawaited(_convexUpdate(taskId, {'isDone': next}));
      return;
    }
    _tasks[index] = item.copyWith(isDone: next);
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  void deleteTask(String taskId) {
    if (_useConvex) {
      _selectedTaskIds.remove(taskId);
      notifyListeners();
      unawaited(_convexRemoveOne(taskId));
      return;
    }
    _tasks.removeWhere((t) => t.id == taskId);
    _selectedTaskIds.remove(taskId);
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  Future<void> _convexRemoveOne(String taskId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'tasks:remove',
        args: {'id': taskId},
      );
    } catch (e, st) {
      debugPrint('Convex remove: $e\n$st');
    }
  }

  void _recomputeCategoryCounts() {
    for (var i = 0; i < _categories.length; i++) {
      final category = _categories[i];
      final count =
          _tasks.where((t) => t.categoryId == category.id && !t.isDone).length;
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

  /// Для списка: `TODAY` / `TOMORROW` / `8 март` (без времени).
  String formatDueDayLabel(DateTime dueAt) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = DateTime(dueAt.year, dueAt.month, dueAt.day);
    if (isSameCalendarDay(d, today)) return 'TODAY';
    final tomorrow = today.add(const Duration(days: 1));
    if (isSameCalendarDay(d, tomorrow)) return 'TOMORROW';
    return formatDueDay(dueAt);
  }

  /// Одна строка: `TODAY · 14:30` / `TOMORROW · 09:00` / `8 март · 20:34`.
  String formatDueLineCompact(DateTime dueAt) {
    return '${formatDueDayLabel(dueAt)} · ${formatDueTime(dueAt)}';
  }

  IconData iconForCategoryTag(String tag) {
    switch (tag) {
      case 'SHOPPING':
        return Icons.shopping_cart_outlined;
      case 'WORK':
        return Icons.work_outline_rounded;
      case 'HEALTH':
        return Icons.favorite_border_rounded;
      case 'KIDS':
        return Icons.child_care_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  String _tagFromParsedCategory(String category) {
    switch (category) {
      case 'Покупки':
        return 'SHOPPING';
      case 'Работа':
        return 'WORK';
      case 'Здоровье':
        return 'HEALTH';
      case 'Дети':
        return 'KIDS';
      default:
        return 'GENERAL';
    }
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
        return 'general';
    }
  }
}

double bubbleFloatDurationMs(String categoryId) {
  final seed = categoryId.hashCode.abs();
  return (4800 + Random(seed).nextInt(2400)).toDouble();
}
