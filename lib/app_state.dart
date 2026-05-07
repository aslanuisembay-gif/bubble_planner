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
import 'planner_languages.dart';
import 'translations.dart' as app_tr;
import 'app_theme.dart' show AppColorPaletteId, AppFontChoice;
import 'bubble_planner_personas.dart';

export 'app_theme.dart' show AppColorPaletteId, AppFontChoice, BubblePlannerColors;
export 'bubble_planner_personas.dart' show BubblePlannerPersona;

/// Sentinel for [BubbleTaskItem.copyWith] when `null` should mean "clear field".
const Object _kTaskCopyUnset = Object();

enum SettingsTab { appearance, routines, language, legal, feedback }

enum TaskListFilter { all, active, done }

/// Вид списка задач: обычный список / неделя / месяц.
enum TasksCalendarMode { day, week, month }

enum BubbleThemeMode { system, light, dark }

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

IconData routineIconFromKey(String key) {
  switch (key) {
    case 'sun':
      return Icons.wb_sunny_rounded;
    case 'work':
      return Icons.work_outline_rounded;
    case 'moon':
      return Icons.nights_stay_outlined;
    case 'fitness':
      return Icons.fitness_center_rounded;
    case 'book':
      return Icons.menu_book_rounded;
    case 'coffee':
      return Icons.local_cafe_rounded;
    default:
      return Icons.schedule_rounded;
  }
}

class RoutineItem {
  RoutineItem({
    required this.id,
    required this.iconKey,
    required this.title,
    required this.timeRange,
    required this.startHour,
    required this.startMinute,
  });

  final String id;
  final String iconKey;
  final String title;
  final String timeRange;
  /// Время «срока» рутины в списке задач на сегодня.
  final int startHour;
  final int startMinute;

  IconData get icon => routineIconFromKey(iconKey);

  RoutineItem copyWith({
    String? id,
    String? iconKey,
    String? title,
    String? timeRange,
    int? startHour,
    int? startMinute,
  }) {
    return RoutineItem(
      id: id ?? this.id,
      iconKey: iconKey ?? this.iconKey,
      title: title ?? this.title,
      timeRange: timeRange ?? this.timeRange,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'iconKey': iconKey,
        'title': title,
        'timeRange': timeRange,
        'startHour': startHour,
        'startMinute': startMinute,
      };

  factory RoutineItem.fromJson(Map<String, dynamic> m) {
    return RoutineItem(
      id: '${m['id']}',
      iconKey: '${m['iconKey'] ?? 'sun'}',
      title: '${m['title'] ?? ''}',
      timeRange: '${m['timeRange'] ?? ''}',
      startHour: (m['startHour'] as num?)?.toInt() ?? 7,
      startMinute: (m['startMinute'] as num?)?.toInt() ?? 0,
    );
  }
}

List<RoutineItem> _defaultRoutineList() => [
      RoutineItem(
        id: 'morning',
        iconKey: 'sun',
        title: 'Morning Focus',
        timeRange: '07:00 - 09:00',
        startHour: 7,
        startMinute: 0,
      ),
      RoutineItem(
        id: 'work',
        iconKey: 'work',
        title: 'Deep Work',
        timeRange: '10:00 - 13:00',
        startHour: 10,
        startMinute: 0,
      ),
      RoutineItem(
        id: 'evening',
        iconKey: 'moon',
        title: 'Evening Wind Down',
        timeRange: '20:00 - 22:00',
        startHour: 20,
        startMinute: 0,
      ),
    ];

List<int>? _normalizeReminderOffsets(Iterable<int>? raw) {
  if (raw == null) return null;
  const ok = {5, 30, 60};
  final out = raw.where(ok.contains).toSet().toList()..sort();
  return out.isEmpty ? null : out;
}

List<int>? _inferReminderOffsetsFromLegacy(DateTime due, DateTime remAt) {
  final mins = due.difference(remAt).inMinutes;
  if (mins < 0 || mins > 24 * 60) return null;
  const opts = [5, 30, 60];
  final matches = <int>[];
  for (final o in opts) {
    if ((mins - o).abs() <= 2) {
      matches.add(o);
    }
  }
  if (matches.isNotEmpty) {
    return matches;
  }
  final nearest = opts.reduce((a, b) => (mins - a).abs() <= (mins - b).abs() ? a : b);
  return [nearest];
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
    this.reminderOffsets,
  });

  final String id;
  final String categoryId;
  final String categoryTag;
  final String title;
  final DateTime dueAt;
  final bool isDone;
  final List<String>? recurrenceDays;
  /// Minutes before due: only 5, 30, 60 — several can be active at once.
  final List<int>? reminderOffsets;

  BubbleTaskItem copyWith({
    String? id,
    String? categoryId,
    String? categoryTag,
    String? title,
    DateTime? dueAt,
    bool? isDone,
    Object? recurrenceDays = _kTaskCopyUnset,
    Object? reminderOffsets = _kTaskCopyUnset,
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
      reminderOffsets: identical(reminderOffsets, _kTaskCopyUnset)
          ? this.reminderOffsets
          : _normalizeReminderOffsets(reminderOffsets as List<int>?),
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
        if (reminderOffsets != null && reminderOffsets!.isNotEmpty) 'reminderOffsets': reminderOffsets,
      };

  factory BubbleTaskItem.fromJson(Map<String, dynamic> m) {
    List<String>? rd;
    final r = m['recurrenceDays'];
    if (r is List) {
      rd = r.map((e) => e.toString()).toList();
    }
    final dueRaw = m['dueAtMs'];
    final dueMs = dueRaw is num ? dueRaw.toInt() : int.parse('$dueRaw');
    final due = DateTime.fromMillisecondsSinceEpoch(dueMs);

    List<int>? ro;
    final roRaw = m['reminderOffsets'];
    if (roRaw is List && roRaw.isNotEmpty) {
      ro = _normalizeReminderOffsets(roRaw.map((e) => (e as num).toInt()));
    }
    if (ro == null || ro.isEmpty) {
      final rem = m['reminderAtMs'];
      if (rem != null) {
        final remAt = DateTime.fromMillisecondsSinceEpoch(
          rem is num ? rem.toInt() : int.parse('$rem'),
        );
        ro = _inferReminderOffsetsFromLegacy(due, remAt);
      }
    }

    return BubbleTaskItem(
      id: '${m['id']}',
      categoryId: '${m['categoryId']}',
      categoryTag: '${m['categoryTag']}',
      title: '${m['title']}',
      dueAt: due,
      isDone: m['isDone'] as bool? ?? false,
      recurrenceDays: rd,
      reminderOffsets: ro,
    );
  }
}

class NoteItem {
  NoteItem({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.folder = 'General',
    this.tags = const [],
    this.imagesBase64 = const [],
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final String folder;
  final List<String> tags;
  final List<String> imagesBase64;

  NoteItem copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    String? folder,
    List<String>? tags,
    List<String>? imagesBase64,
  }) {
    return NoteItem(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
      imagesBase64: imagesBase64 ?? this.imagesBase64,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAtMs': createdAt.millisecondsSinceEpoch,
        'updatedAtMs': updatedAt.millisecondsSinceEpoch,
        'title': title,
        'folder': folder,
        'tags': tags,
        'imagesBase64': imagesBase64,
      };

  factory NoteItem.fromJson(Map<String, dynamic> m) {
    final imgs = m['imagesBase64'];
    final tagsRaw = m['tags'];
    return NoteItem(
      id: '${m['id']}',
      text: '${m['text'] ?? ''}',
      createdAt: DateTime.fromMillisecondsSinceEpoch((m['createdAtMs'] as num).toInt()),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((m['updatedAtMs'] as num).toInt()),
      title: '${m['title'] ?? ''}',
      folder: '${m['folder'] ?? 'General'}',
      tags: tagsRaw is List ? tagsRaw.map((e) => '$e').toList() : const [],
      imagesBase64: imgs is List ? imgs.map((e) => '$e').toList() : const [],
    );
  }
}

class UserProfileData {
  const UserProfileData({
    this.displayName = '',
    this.avatarBase64,
  });

  final String displayName;
  final String? avatarBase64;

  UserProfileData copyWith({
    String? displayName,
    Object? avatarBase64 = _kTaskCopyUnset,
  }) {
    return UserProfileData(
      displayName: displayName ?? this.displayName,
      avatarBase64: identical(avatarBase64, _kTaskCopyUnset)
          ? this.avatarBase64
          : avatarBase64 as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'avatarBase64': avatarBase64,
      };

  factory UserProfileData.fromJson(Map<String, dynamic> m) {
    return UserProfileData(
      displayName: '${m['displayName'] ?? ''}',
      avatarBase64: m['avatarBase64'] == null ? null : '${m['avatarBase64']}',
    );
  }
}

class AppState extends ChangeNotifier {
  AppState() {
    _rebuildCategoriesFromPersona();
    _recomputeCategoryCounts();
    unawaited(_bootstrapSession());
    unawaited(_loadLegalConsent());
    unawaited(_loadLanguage());
    unawaited(_syncPersonaFromDisk());
    unawaited(_loadColorPalette());
    unawaited(_loadThemeMode());
    unawaited(_loadNotes());
    unawaited(_loadDailyRoutines());
    unawaited(_loadCalendarViewPrefs());
    unawaited(_loadRoutinesPrefs());
    unawaited(_loadRoutineDonePrefs());
    unawaited(_loadPersonaSlotsPrefs());
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
      _isLoggedIn = true;
      _localDemoSession = false;
      await _loadLocalUserProfile();
      _convexLoading = true;
      notifyListeners();
      await _syncPersonaFromDisk();
      await Future.wait<void>([
        _loadLanguage(),
        _loadUserProfile(),
        _restoreCloudTasksCache(),
      ]);
      if (_localDemoSession) {
        _stopConvexSync();
        _convexLoading = false;
        _recomputeCategoryCounts();
        notifyListeners();
        return;
      }
      try {
        await Future.wait<void>([
          _convexHydrateTasksFromQuery(),
          _convexHydrateNotesFromQuery(),
        ]);
      } catch (e, st) {
        debugPrint('_bootstrapSession hydrate: $e\n$st');
      }
      _convexLoading = false;
      _recomputeCategoryCounts();
      notifyListeners();
      unawaited(_convexStartLiveSubscriptionsBackground());
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
  TasksCalendarMode _tasksCalendarMode = TasksCalendarMode.day;
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
  void Function()? _cancelNotesSub;
  UserProfileData _userProfile = const UserProfileData();

  static const String _kPrefsLocalTasks = 'bubble_planner_local_tasks_v1';
  static const String _kPrefsLocalIdSeed = 'bubble_planner_local_id_seed_v1';
  static const String _kPrefsLegalConsent = 'bubble_planner_legal_consent_v1';
  static const String _kPrefsLanguage = 'bubble_planner_language_v1';
  static const String _kPrefsColorPalette = 'bubble_planner_color_palette_v1';
  static const String _kPrefsNotes = 'bubble_planner_notes_v1';
  static const String _kPrefsDailyRoutines = 'bubble_planner_daily_routines_v1';
  static const String _kPrefsTasksCalendarMode = 'bubble_planner_tasks_calendar_mode_v1';
  static const String _kPrefsCalendarWeekView = 'bubble_planner_calendar_week_v1';
  static const String _kPrefsCalendarMonthView = 'bubble_planner_calendar_month_v1';
  static const String _kPrefsRoutinesList = 'bubble_planner_routines_list_v1';
  static const String _kPrefsRoutineDone = 'bubble_planner_routine_done_v1';
  static const String _kPrefsBubblePersona = 'bubble_planner_persona_v1';
  static const String _kPrefsThemeMode = 'bubble_planner_theme_mode_v1';
  static const String _kPrefsUserProfile = 'bubble_planner_user_profile_v1';
  static const String _kPrefsPersonaSlots = 'bubble_planner_persona_slots_v1';
  static const String _kPrefsCloudTasksCache = 'bubble_planner_cloud_tasks_cache_v1';

  bool _legalConsentAccepted = false;
  String _languageCode = 'en';
  AppColorPaletteId _colorPaletteId = AppColorPaletteId.classic;
  BubbleThemeMode _themeMode = BubbleThemeMode.system;
  BubblePlannerPersona _bubblePlannerPersona = BubblePlannerPersona.general;

  final List<BubbleCategory> _categories = [];
  final Map<BubblePlannerPersona, List<BubbleSlotLayout>> _personaSlotsOverride = {};

  List<RoutineItem> _routines = _defaultRoutineList();
  /// taskId `rt_*` → день `yyyy-m-d`, когда отмечено «готово» (скрыто до следующего дня).
  final Map<String, String> _routineDoneDayKey = {};

  final List<BubbleTaskItem> _tasks = [];
  final List<NoteItem> _notes = [];

  AppFontChoice get fontChoice => _fontChoice;
  bool get dailyRoutinesEnabled => _dailyRoutinesEnabled;
  /// Режим календаря на вкладке задач: день / неделя / месяц.
  TasksCalendarMode get tasksCalendarMode => _tasksCalendarMode;
  bool get voiceActivationEnabled => _voiceActivationEnabled;
  SettingsTab get activeSettingsTab => _activeSettingsTab;
  bool get legalConsentAccepted => _legalConsentAccepted;
  /// Код языка интерфейса: `en` или `ru`.
  String get languageCode => _languageCode;
  /// Активная цветовая палитра (оформление).
  AppColorPaletteId get colorPaletteId => _colorPaletteId;
  BubbleThemeMode get themeMode => _themeMode;
  BubblePlannerPersona get bubblePlannerPersona => _bubblePlannerPersona;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  List<BubbleCategory> get categories => _categories;
  List<RoutineItem> get routines => List.unmodifiable(_routines);
  List<BubbleTaskItem> get tasks => List.unmodifiable(_tasks);
  List<NoteItem> get notes => List.unmodifiable(_notes);
  bool get isLoggedIn => _isLoggedIn;
  TaskListFilter get listFilter => _listFilter;
  String get searchQuery => _searchQuery;
  Set<String> get selectedTaskIds => Set.unmodifiable(_selectedTaskIds);
  bool get isSelectionMode => _selectedTaskIds.isNotEmpty;

  bool get convexLoading => _convexLoading;
  String? get convexError => _convexError;
  UserProfileData get userProfile => _userProfile;
  String get displayName => _userProfile.displayName.trim();
  String? get avatarBase64 => _userProfile.avatarBase64;
  String get welcomeBackLabel {
    final name = displayName;
    if (name.isNotEmpty) return 'Welcome back, $name!';
    if (_localDemoSession) return 'Welcome back, demo!';
    return 'Welcome back!';
  }

  /// Convex + JWT: задачи в облаке с проверкой на сервере ([getAuthUserId]).
  bool get useConvexBackend =>
      ConvexEnv.isConfigured &&
      ConvexEnv.backendReady &&
      _isLoggedIn &&
      !_localDemoSession;

  bool get _useConvex => useConvexBackend;

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
    _migrateAllTasksToCurrentPersona(persistConvex: false);
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
      _migrateAllTasksToCurrentPersona(persistConvex: false);
    } catch (e, st) {
      debugPrint('_restoreLocalTasksOrSeedDemo: $e\n$st');
      _seedDemoTasks();
      _migrateAllTasksToCurrentPersona(persistConvex: false);
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
    final p = password.trim();
    if (u == 'demo' && p == 'demo') {
      // Сразу, до любых await — иначе _bootstrapSession успевает подписаться на Convex и затирает _tasks.
      _localDemoSession = true;
      _stopConvexSync();
      if (ConvexEnv.isConfigured && ConvexEnv.backendReady) {
        unawaited(ConvexAuthSession.signOut());
      }
      _isLoggedIn = true;
      await _loadLanguage();
      await _syncPersonaFromDisk();
      await _loadUserProfile();
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
    const signInTimeout = Duration(seconds: 18);

    Future<void> finishCloudLogin() async {
      _isLoggedIn = true;
      await _loadLocalUserProfile();
      notifyListeners();
      await _syncPersonaFromDisk();
      await Future.wait<void>([
        _loadLanguage(),
        _loadUserProfile(),
        _restoreCloudTasksCache(),
      ]);
      // Не ждём гидратацию/WS — иначе при зависании query вход «не открывается» (вечный await).
      _convexLoading = false;
      _recomputeCategoryCounts();
      notifyListeners();
      unawaited(_postLoginConvexSync());
    }

    Future<void> signInOnce({
      required bool asSignUp,
      Duration timeout = signInTimeout,
    }) async {
      await ConvexAuthSession.signIn(
        email: u,
        password: p,
        signUp: asSignUp,
      ).timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Sign in timed out. Please refresh and try again.',
        ),
      );
    }

    try {
      await signInOnce(asSignUp: signUp);
      await finishCloudLogin();
      return true;
    } catch (e, st) {
      // Sometimes the account is created server-side but the action response times out on web.
      // In that case, try a normal sign-in once before showing an error.
      if (signUp && e.toString().contains('TimeoutException')) {
        try {
          await signInOnce(
            asSignUp: false,
            timeout: const Duration(seconds: 8),
          );
          await finishCloudLogin();
          return true;
        } catch (_) {
          // Fall through to the original error handling below.
        }
      }
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
    if (e is TimeoutException) {
      final m = e.message?.trim();
      if (m != null && m.isNotEmpty) return m;
      return 'Request timed out. Please try again.';
    }
    var s = e.toString();
    final lower = s.toLowerCase();
    if (lower.contains('websocket not connected')) {
      return 'Connection lost. Please check internet and try again.';
    }
    s = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
    s = s.replaceFirst(RegExp(r'^.*Server Error\s*'), '');
    if (s.trim().isEmpty) {
      return 'Authentication failed. Please try again.';
    }
    if (s.length > 280) {
      s = '${s.substring(0, 280)}…';
    }
    return s.trim();
  }

  Future<void> _loadUserProfile() async {
    await _loadLocalUserProfile();
    if (_useConvex) {
      await _mergeCloudUserProfile();
    }
  }

  Future<void> _mirrorUserProfileToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsUserProfile, jsonEncode(_userProfile.toJson()));
    } catch (e, st) {
      debugPrint('_mirrorUserProfileToPrefs: $e\n$st');
    }
  }

  /// Сервер — источник истины; при пустом облаке поднимаем имя из локального кэша.
  Future<void> _mergeCloudUserProfile() async {
    try {
      final raw = await ConvexClient.instance.query('userProfiles:getMine', {});
      final decoded = jsonDecode(raw);
      if (decoded == null) {
        if (_userProfile.displayName.trim().isNotEmpty) {
          await saveUserProfile(
            displayName: _userProfile.displayName,
            avatarBase64: _userProfile.avatarBase64,
          );
        }
        return;
      }
      final m = Map<String, dynamic>.from(decoded as Map);
      final cloudName = '${m['displayName'] ?? ''}'.trim();
      final cloudAvatar = m['avatarBase64'] == null ? null : '${m['avatarBase64']}';
      if (cloudName.isNotEmpty || (cloudAvatar != null && cloudAvatar.isNotEmpty)) {
        _userProfile = UserProfileData(
          displayName: cloudName.isNotEmpty ? cloudName : _userProfile.displayName,
          avatarBase64: cloudAvatar ?? _userProfile.avatarBase64,
        );
        await _mirrorUserProfileToPrefs();
        notifyListeners();
      }
      if (cloudName.isEmpty && _userProfile.displayName.trim().isNotEmpty) {
        await saveUserProfile(
          displayName: _userProfile.displayName,
          avatarBase64: _userProfile.avatarBase64,
        );
      }
    } catch (e, st) {
      debugPrint('_mergeCloudUserProfile: $e\n$st');
    }
  }

  Future<void> _loadLocalUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsUserProfile);
      if (raw == null || raw.isEmpty) {
        _userProfile = const UserProfileData();
      } else {
        _userProfile = UserProfileData.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadLocalUserProfile: $e\n$st');
    }
  }

  Future<void> saveUserProfile({
    required String displayName,
    String? avatarBase64,
    bool clearAvatar = false,
  }) async {
    final trimmedName = displayName.trim();
    final next = _userProfile.copyWith(
      displayName: trimmedName,
      avatarBase64: clearAvatar ? null : avatarBase64,
    );
    _userProfile = next;
    notifyListeners();
    if (_useConvex) {
      try {
        await ConvexClient.instance.mutation(
          name: 'userProfiles:upsertMine',
          args: {
            'displayName': trimmedName,
            if (!clearAvatar && avatarBase64 != null) 'avatarBase64': avatarBase64,
            if (clearAvatar) 'clearAvatar': true,
          },
        );
        await _mirrorUserProfileToPrefs();
      } catch (e, st) {
        debugPrint('saveUserProfile cloud: $e\n$st');
      }
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsUserProfile, jsonEncode(next.toJson()));
    } catch (e, st) {
      debugPrint('saveUserProfile local: $e\n$st');
    }
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
    _notes.clear();
    _selectedTaskIds.clear();
    _userProfile = const UserProfileData();
    _recomputeCategoryCounts();
    notifyListeners();
  }

  void _stopConvexSync() {
    _cancelTasksSub?.call();
    _cancelTasksSub = null;
    _cancelNotesSub?.call();
    _cancelNotesSub = null;
  }

  bool _isTransientConvexSocketError(Object e) {
    final s = e.toString();
    return s.contains('WebSocket not connected') ||
        s.contains('TimeoutException') ||
        s.contains('Connection timeout');
  }

  Future<T> _runWithConvexReconnectRetry<T>(
    Future<T> Function() op, {
    int retries = 2,
  }) async {
    Object? lastError;
    for (var i = 0; i <= retries; i++) {
      try {
        return await op();
      } catch (e) {
        lastError = e;
        if (i >= retries || !_isTransientConvexSocketError(e)) rethrow;
        try {
          await ConvexClient.instance.reconnect();
        } catch (_) {
          // Best-effort reconnect before retry.
        }
        await Future<void>.delayed(Duration(milliseconds: 450 * (i + 1)));
      }
    }
    throw lastError ?? Exception('Convex operation failed');
  }

  Future<void> _convexSubscribeTasks() async {
    _cancelTasksSub?.call();
    _cancelTasksSub = null;
    final handle = await _runWithConvexReconnectRetry(
      () => ConvexClient.instance.subscribe(
      name: 'tasks:listForUser',
      args: {},
      onUpdate: (json) {
        try {
          _setTasksFromConvexRaw(json);
        } catch (e, st) {
          debugPrint('Convex list parse: $e\n$st');
        }
      },
      onError: (message, value) {
        debugPrint('Convex subscription error: $message value=$value');
      },
      ),
    );
    _cancelTasksSub = () {
      handle.cancel();
      _cancelTasksSub = null;
    };
  }

  Future<void> _convexSubscribeNotes() async {
    _cancelNotesSub?.call();
    _cancelNotesSub = null;
    final handle = await _runWithConvexReconnectRetry(
      () => ConvexClient.instance.subscribe(
      name: 'notes:listForUser',
      args: {},
      onUpdate: (json) {
        try {
          _setNotesFromConvexRaw(json);
        } catch (e, st) {
          debugPrint('Convex notes parse: $e\n$st');
        }
      },
      onError: (message, value) {
        debugPrint('Convex notes subscription error: $message value=$value');
      },
      ),
    );
    _cancelNotesSub = () {
      handle.cancel();
      _cancelNotesSub = null;
    };
  }

  /// После email-входа: запросы к Convex в фоне с таймаутом, чтобы не блокировать [tryLogin].
  Future<void> _postLoginConvexSync() async {
    try {
      await Future.wait<void>([
        _convexHydrateTasksFromQuery().timeout(const Duration(seconds: 20)),
        _convexHydrateNotesFromQuery().timeout(const Duration(seconds: 20)),
      ]);
    } catch (e, st) {
      debugPrint('_postLoginConvexSync hydrate: $e\n$st');
    }
    notifyListeners();
    unawaited(() async {
      try {
        await Future.wait<void>([
          _convexSubscribeTasks().timeout(const Duration(seconds: 8)),
          _convexSubscribeNotes().timeout(const Duration(seconds: 8)),
        ]);
        _convexError = null;
        notifyListeners();
      } on TimeoutException catch (e, st) {
        debugPrint('Convex subscribe timeout after login: $e\n$st');
        _convexError =
            'Signed in, but live sync is slow. Your lists will load shortly — try reopening the tab if empty.';
        notifyListeners();
        _scheduleConvexResubscribe();
      } catch (e, st) {
        debugPrint('Convex subscribe after login: $e\n$st');
        _scheduleConvexResubscribe();
      }
    }());
  }

  /// Live WebSocket — в фоне, чтобы первый кадр с задачами не ждал подключения минутами.
  Future<void> _convexStartLiveSubscriptionsBackground() async {
    try {
      await Future.wait<void>([
        _convexSubscribeTasks().timeout(const Duration(seconds: 8)),
        _convexSubscribeNotes().timeout(const Duration(seconds: 8)),
      ]);
      if (useConvexBackend) {
        _convexError = null;
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('Convex live subscribe: $e\n$st');
      _scheduleConvexResubscribe();
    }
  }

  /// Retries live subscriptions after a flaky login (web socket / slow network).
  void _scheduleConvexResubscribe() {
    unawaited(() async {
      for (var attempt = 0; attempt < 6; attempt++) {
        await Future<void>.delayed(Duration(seconds: 2 + attempt));
        if (!useConvexBackend) return;
        try {
          await Future.wait<void>([
            _convexSubscribeTasks().timeout(const Duration(seconds: 8)),
            _convexSubscribeNotes().timeout(const Duration(seconds: 8)),
          ]);
          if (useConvexBackend) {
            _convexError = null;
            notifyListeners();
          }
          return;
        } catch (e, st) {
          debugPrint('_scheduleConvexResubscribe attempt $attempt: $e\n$st');
        }
      }
    }());
  }

  List<NoteItem> _parseNotesFromConvexJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final tags = m['tags'];
      final images = m['imagesBase64'];
      return NoteItem(
        id: '${m['_id']}',
        text: '${m['text'] ?? ''}',
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['createdAtMs'] as num).toInt()),
        updatedAt: DateTime.fromMillisecondsSinceEpoch((m['updatedAtMs'] as num).toInt()),
        title: '${m['title'] ?? ''}',
        folder: '${m['folder'] ?? 'General'}',
        tags: tags is List ? tags.map((x) => '$x').toList() : const [],
        imagesBase64: images is List ? images.map((x) => '$x').toList() : const [],
      );
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
      final due = DateTime.fromMillisecondsSinceEpoch(
        (m['dueAtMs'] as num).toInt(),
      );
      List<int>? ro;
      final roRaw = m['reminderOffsets'];
      if (roRaw is List && roRaw.isNotEmpty) {
        ro = _normalizeReminderOffsets(roRaw.map((e) => (e as num).toInt()));
      }
      if (ro == null || ro.isEmpty) {
        final rem = m['reminderAtMs'];
        if (rem is num) {
          final remAt = DateTime.fromMillisecondsSinceEpoch(rem.toInt());
          ro = _inferReminderOffsetsFromLegacy(due, remAt);
        }
      }
      return BubbleTaskItem(
        id: id,
        categoryId: m['categoryId'] as String,
        categoryTag: m['categoryTag'] as String,
        title: m['title'] as String,
        dueAt: due,
        isDone: m['isDone'] as bool,
        recurrenceDays: rd,
        reminderOffsets: ro,
      );
    }).toList();
  }

  void _setTasksFromConvexRaw(String raw) {
    final next = _parseTasksFromConvexJson(raw);
    _tasks
      ..clear()
      ..addAll(next);
    _migrateAllTasksToCurrentPersona(persistConvex: _useConvex);
    _recomputeCategoryCounts();
    notifyListeners();
    unawaited(_cacheCloudTasksRaw(raw));
  }

  Future<void> _cacheCloudTasksRaw(String raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsCloudTasksCache, raw);
    } catch (_) {}
  }

  Future<void> _restoreCloudTasksCache() async {
    if (!_useConvex) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsCloudTasksCache);
      if (raw == null || raw.isEmpty) return;
      _setTasksFromConvexRaw(raw);
    } catch (e, st) {
      debugPrint('_restoreCloudTasksCache: $e\n$st');
    }
  }

  void _setNotesFromConvexRaw(String raw) {
    final next = _parseNotesFromConvexJson(raw);
    _notes
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// Начало календарного дня в локальном времени.
  DateTime calendarDayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Просроченные невыполненные (для блока «Требует внимания»). Рутины не считаем.
  bool isAttentionOverdueTask(BubbleTaskItem t, DateTime todayStart) {
    if (t.isDone) return false;
    if (t.id.startsWith('rt_')) return false;
    final dueDay = calendarDayStart(t.dueAt);
    return dueDay.isBefore(todayStart);
  }

  /// Дата срока строго после сегодняшнего дня («следующие дни»).
  bool isFutureCalendarDayTask(BubbleTaskItem t, DateTime todayStart) {
    final dueDay = calendarDayStart(t.dueAt);
    return dueDay.isAfter(todayStart);
  }

  Future<void> _convexHydrateTasksFromQuery() async {
    if (!_useConvex) return;
    try {
      final raw = await ConvexClient.instance.query('tasks:listForUser', {});
      _setTasksFromConvexRaw(raw);
    } catch (e, st) {
      debugPrint('_convexHydrateTasksFromQuery: $e\n$st');
      try {
        final raw = await _runWithConvexReconnectRetry(
          () => ConvexClient.instance.query('tasks:listForUser', {}),
        );
        _setTasksFromConvexRaw(raw);
      } catch (e2, st2) {
        debugPrint('_convexHydrateTasksFromQuery retry: $e2\n$st2');
      }
    }
  }

  Future<void> _convexHydrateNotesFromQuery() async {
    if (!_useConvex) return;
    try {
      final raw = await ConvexClient.instance.query('notes:listForUser', {});
      _setNotesFromConvexRaw(raw);
    } catch (e, st) {
      debugPrint('_convexHydrateNotesFromQuery: $e\n$st');
      try {
        final raw = await _runWithConvexReconnectRetry(
          () => ConvexClient.instance.query('notes:listForUser', {}),
        );
        _setNotesFromConvexRaw(raw);
      } catch (e2, st2) {
        debugPrint('_convexHydrateNotesFromQuery retry: $e2\n$st2');
      }
    }
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
    final lines = <String>[];
    for (final t in _tasks) {
      if (set.contains(t.id)) {
        lines.add(t.title);
      }
    }
    for (final id in set) {
      if (id.startsWith('rt_')) {
        final rid = id.replaceFirst('rt_', '');
        final i = _routines.indexWhere((e) => e.id == rid);
        if (i >= 0) {
          lines.add(_routines[i].title);
        }
      }
    }
    return lines.join('\n');
  }

  void deleteTasksByIds(Iterable<String> ids) {
    final list = ids.toList();
    for (final id in list) {
      if (id.startsWith('rt_')) {
        removeRoutine(id.replaceFirst('rt_', ''));
      }
    }
    final rest = list.where((id) => !id.startsWith('rt_')).toList();
    if (rest.isEmpty) return;
    if (_useConvex) {
      final set = rest.toSet();
      _tasks.removeWhere((t) => set.contains(t.id));
      _selectedTaskIds.removeWhere(set.contains);
      _recomputeCategoryCounts();
      notifyListeners();
      unawaited(_convexRemoveMany(rest));
      return;
    }
    final set = rest.toSet();
    _tasks.removeWhere((t) => set.contains(t.id));
    _selectedTaskIds.removeWhere(set.contains);
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  Future<void> _convexRemoveMany(Iterable<String> ids) async {
    final filtered = ids.where((id) => !id.startsWith('rt_')).toList();
    if (filtered.isEmpty) return;
    try {
      await ConvexClient.instance.mutation(
        name: 'tasks:removeMany',
        args: {
          'ids': filtered,
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

  Future<void> _loadColorPalette() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefsColorPalette);
      final next = _parseColorPaletteId(raw);
      if (next != _colorPaletteId) {
        _colorPaletteId = next;
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('_loadColorPalette: $e\n$st');
    }
  }

  AppColorPaletteId _parseColorPaletteId(String? raw) {
    switch (raw) {
      case 'wellnessMint':
        return AppColorPaletteId.wellnessMint;
      case 'softLavender':
        return AppColorPaletteId.softLavender;
      case 'oceanBreeze':
        return AppColorPaletteId.oceanBreeze;
      case 'sunsetCoral':
        return AppColorPaletteId.sunsetCoral;
      case 'midnightNeon':
        return AppColorPaletteId.midnightNeon;
      case 'forestMoss':
        return AppColorPaletteId.forestMoss;
      case 'monochromeInk':
        return AppColorPaletteId.monochromeInk;
      case 'peachSorbet':
        return AppColorPaletteId.peachSorbet;
      case 'classic':
      default:
        return AppColorPaletteId.classic;
    }
  }

  Future<void> setColorPaletteId(AppColorPaletteId id) async {
    if (_colorPaletteId == id) return;
    _colorPaletteId = id;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kPrefsColorPalette, id.name);
    } catch (e, st) {
      debugPrint('setColorPaletteId: $e\n$st');
    }
  }

  Future<void> _loadThemeMode() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefsThemeMode);
      switch (raw) {
        case 'light':
          _themeMode = BubbleThemeMode.light;
          break;
        case 'dark':
          _themeMode = BubbleThemeMode.dark;
          break;
        case 'system':
        default:
          _themeMode = BubbleThemeMode.system;
          break;
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadThemeMode: $e\n$st');
    }
  }

  Future<void> setThemeMode(BubbleThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kPrefsThemeMode, mode.name);
    } catch (e, st) {
      debugPrint('setThemeMode: $e\n$st');
    }
  }

  void setActiveSettingsTab(SettingsTab tab) {
    _activeSettingsTab = tab;
    notifyListeners();
  }

  Future<void> _loadLanguage() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(_kPrefsLanguage);
      if (saved != null && isPlannerLanguageCode(saved)) {
        _languageCode = saved;
      }
      app_tr.currentLanguageCode = _languageCode;
      _rebuildCategoriesFromPersona();
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadLanguage: $e\n$st');
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (!isPlannerLanguageCode(code)) return;
    if (_languageCode == code) return;
    _languageCode = code;
    app_tr.currentLanguageCode = code;
    _rebuildCategoriesFromPersona();
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kPrefsLanguage, code);
    } catch (e, st) {
      debugPrint('setLanguageCode: $e\n$st');
    }
  }

  Future<void> _loadLegalConsent() async {
    try {
      final p = await SharedPreferences.getInstance();
      _legalConsentAccepted = p.getBool(_kPrefsLegalConsent) ?? false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadLegalConsent: $e\n$st');
    }
  }

  Future<void> _loadNotes() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefsNotes);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _notes
        ..clear()
        ..addAll(decoded.map((e) => NoteItem.fromJson(Map<String, dynamic>.from(e as Map))));
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadNotes: $e\n$st');
    }
  }

  Future<void> _saveNotes() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = jsonEncode(_notes.map((e) => e.toJson()).toList());
      await p.setString(_kPrefsNotes, raw);
    } catch (e, st) {
      debugPrint('_saveNotes: $e\n$st');
    }
  }

  Future<String> createNoteFromVoice(String text) async {
    if (_useConvex) {
      final now = DateTime.now();
      try {
        final createdId = await ConvexClient.instance.mutation(
          name: 'notes:create',
          args: {
            'title': '',
            'text': text.trim(),
            'folder': 'General',
            'tags': const <String>[],
          },
        );
        return createdId.toString();
      } catch (e, st) {
        debugPrint('Convex notes create: $e\n$st');
      }
      final fallbackId = 'n_${now.millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
      _notes.insert(
        0,
        NoteItem(
          id: fallbackId,
          text: text.trim(),
          createdAt: now,
          updatedAt: now,
          title: '',
          folder: 'General',
        ),
      );
      notifyListeners();
      return fallbackId;
    }
    final now = DateTime.now();
    final id = 'n_${now.millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
    _notes.insert(
      0,
      NoteItem(
        id: id,
        text: text.trim(),
        createdAt: now,
        updatedAt: now,
        title: '',
        folder: 'General',
      ),
    );
    notifyListeners();
    unawaited(_saveNotes());
    return id;
  }

  String _nextAutoNoteTitle() {
    final used = _notes.map((n) => n.title.trim().toLowerCase()).toSet();
    const base = 'Note';
    if (!used.contains(base.toLowerCase())) return base;
    for (var i = 2; i < 10000; i++) {
      final candidate = '$base $i';
      if (!used.contains(candidate.toLowerCase())) return candidate;
    }
    return 'Note ${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> createEmptyNote() async {
    final autoTitle = _nextAutoNoteTitle();
    if (_useConvex) {
      final now = DateTime.now();
      try {
        final createdId = await ConvexClient.instance.mutation(
          name: 'notes:create',
          args: {
            'title': autoTitle,
            'text': '',
            'folder': 'General',
            'tags': const <String>[],
          },
        );
        return createdId.toString();
      } catch (e, st) {
        debugPrint('Convex empty note create: $e\n$st');
      }
      final fallbackId = 'n_${now.millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
      _notes.insert(
        0,
        NoteItem(
          id: fallbackId,
          title: autoTitle,
          text: '',
          createdAt: now,
          updatedAt: now,
          folder: 'General',
        ),
      );
      notifyListeners();
      return fallbackId;
    }

    final now = DateTime.now();
    final id = 'n_${now.millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
    _notes.insert(
      0,
      NoteItem(
        id: id,
        title: autoTitle,
        text: '',
        createdAt: now,
        updatedAt: now,
        folder: 'General',
      ),
    );
    notifyListeners();
    unawaited(_saveNotes());
    return id;
  }

  void updateNoteText(String noteId, String text) {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    final current = _notes[i];
    _notes[i] = current.copyWith(
      text: text,
      updatedAt: DateTime.now(),
    );
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    if (_useConvex) {
      unawaited(
        ConvexClient.instance.mutation(
          name: 'notes:updateFields',
          args: {'id': noteId, 'text': text},
        ),
      );
    } else {
      unawaited(_saveNotes());
    }
  }

  /// Atomically update note text and inline images (keeps `[photo]` markers and image order in sync).
  void updateNoteContent(
    String noteId, {
    required String text,
    required List<String> imagesBase64,
  }) {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    final current = _notes[i];
    _notes[i] = current.copyWith(
      text: text,
      imagesBase64: imagesBase64,
      updatedAt: DateTime.now(),
    );
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    if (_useConvex) {
      unawaited(
        ConvexClient.instance.mutation(
          name: 'notes:updateFields',
          args: {
            'id': noteId,
            'text': text,
            'imagesBase64': imagesBase64,
          },
        ),
      );
    } else {
      unawaited(_saveNotes());
    }
  }

  void addNoteImageBase64(String noteId, String imageBase64) {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    final current = _notes[i];
    final nextImages = [...current.imagesBase64, imageBase64];
    _notes[i] = current.copyWith(
      imagesBase64: nextImages,
      updatedAt: DateTime.now(),
    );
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    if (_useConvex) {
      unawaited(
        ConvexClient.instance.mutation(
          name: 'notes:addImage',
          args: {'id': noteId, 'imageBase64': imageBase64},
        ),
      );
    } else {
      unawaited(_saveNotes());
    }
  }

  void updateNoteMeta(String noteId, {String? title, String? folder, List<String>? tags}) {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    final current = _notes[i];
    _notes[i] = current.copyWith(
      title: title?.trim() ?? current.title,
      folder: folder == null || folder.trim().isEmpty ? current.folder : folder.trim(),
      tags: tags ?? current.tags,
      updatedAt: DateTime.now(),
    );
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    if (_useConvex) {
      unawaited(
        ConvexClient.instance.mutation(
          name: 'notes:updateFields',
          args: {
            'id': noteId,
            if (title != null) 'title': title.trim(),
            if (folder != null && folder.trim().isNotEmpty) 'folder': folder.trim(),
            if (tags != null) 'tags': tags,
          },
        ),
      );
    } else {
      unawaited(_saveNotes());
    }
  }

  List<NoteItem> filteredNotes({String query = '', String folder = 'all'}) {
    final q = query.trim().toLowerCase();
    return _notes.where((n) {
      final byFolder = folder == 'all' || n.folder.toLowerCase() == folder.toLowerCase();
      if (!byFolder) return false;
      if (q.isEmpty) return true;
      final inText = n.text.toLowerCase().contains(q);
      final inTags = n.tags.any((t) => t.toLowerCase().contains(q));
      final inFolder = n.folder.toLowerCase().contains(q);
      return inText || inTags || inFolder;
    }).toList();
  }

  void removeNoteImageAt(String noteId, int imageIndex) {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    final current = _notes[i];
    if (imageIndex < 0 || imageIndex >= current.imagesBase64.length) return;
    final next = [...current.imagesBase64]..removeAt(imageIndex);
    _notes[i] = current.copyWith(
      imagesBase64: next,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    if (_useConvex) {
      unawaited(
        ConvexClient.instance.mutation(
          name: 'notes:removeImageAt',
          args: {'id': noteId, 'imageIndex': imageIndex},
        ),
      );
    } else {
      unawaited(_saveNotes());
    }
  }

  void deleteNote(String noteId) {
    _notes.removeWhere((n) => n.id == noteId);
    notifyListeners();
    if (_useConvex) {
      unawaited(
        ConvexClient.instance.mutation(
          name: 'notes:remove',
          args: {'id': noteId},
        ),
      );
    } else {
      unawaited(_saveNotes());
    }
  }

  /// Фиксация согласия с текстом на вкладке «Право и данные».
  Future<void> acceptLegalConsent() async {
    _legalConsentAccepted = true;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kPrefsLegalConsent, true);
    } catch (e, st) {
      debugPrint('acceptLegalConsent: $e\n$st');
    }
  }

  Future<void> _loadDailyRoutines() async {
    try {
      final p = await SharedPreferences.getInstance();
      _dailyRoutinesEnabled = p.getBool(_kPrefsDailyRoutines) ?? true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadDailyRoutines: $e\n$st');
    }
  }

  void toggleDailyRoutines(bool value) {
    _dailyRoutinesEnabled = value;
    _recomputeCategoryCounts();
    notifyListeners();
    unawaited(_saveDailyRoutines(value));
  }

  Future<void> _saveDailyRoutines(bool value) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kPrefsDailyRoutines, value);
    } catch (e, st) {
      debugPrint('_saveDailyRoutines: $e\n$st');
    }
  }

  Future<void> _loadCalendarViewPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_kPrefsTasksCalendarMode);
      if (s == 'week') {
        _tasksCalendarMode = TasksCalendarMode.week;
      } else if (s == 'month') {
        _tasksCalendarMode = TasksCalendarMode.month;
      } else if (s == 'day') {
        _tasksCalendarMode = TasksCalendarMode.day;
      } else {
        final w = p.getBool(_kPrefsCalendarWeekView) ?? false;
        final m = p.getBool(_kPrefsCalendarMonthView) ?? false;
        if (w) {
          _tasksCalendarMode = TasksCalendarMode.week;
        } else if (m) {
          _tasksCalendarMode = TasksCalendarMode.month;
        } else {
          _tasksCalendarMode = TasksCalendarMode.day;
        }
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadCalendarViewPrefs: $e\n$st');
    }
  }

  void setTasksCalendarMode(TasksCalendarMode mode) {
    if (_tasksCalendarMode == mode) return;
    _tasksCalendarMode = mode;
    notifyListeners();
    unawaited(_saveTasksCalendarMode());
  }

  Future<void> _saveTasksCalendarMode() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = switch (_tasksCalendarMode) {
        TasksCalendarMode.day => 'day',
        TasksCalendarMode.week => 'week',
        TasksCalendarMode.month => 'month',
      };
      await p.setString(_kPrefsTasksCalendarMode, s);
      await p.remove(_kPrefsCalendarWeekView);
      await p.remove(_kPrefsCalendarMonthView);
    } catch (e, st) {
      debugPrint('_saveTasksCalendarMode: $e\n$st');
    }
  }

  void toggleVoiceActivation(bool value) {
    _voiceActivationEnabled = value;
    notifyListeners();
  }

  Future<void> _loadRoutinesPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefsRoutinesList);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final next = <RoutineItem>[];
      for (final e in decoded) {
        if (e is Map) {
          next.add(RoutineItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      _routines = next;
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadRoutinesPrefs: $e\n$st');
    }
  }

  Future<void> _saveRoutinesList() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = jsonEncode(_routines.map((e) => e.toJson()).toList());
      await p.setString(_kPrefsRoutinesList, raw);
    } catch (e, st) {
      debugPrint('_saveRoutinesList: $e\n$st');
    }
  }

  Future<void> _loadRoutineDonePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefsRoutineDone);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _routineDoneDayKey
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry('$k', '$v')));
      _recomputeCategoryCounts();
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadRoutineDonePrefs: $e\n$st');
    }
  }

  Future<void> _saveRoutineDonePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = jsonEncode(_routineDoneDayKey);
      await p.setString(_kPrefsRoutineDone, raw);
    } catch (e, st) {
      debugPrint('_saveRoutineDonePrefs: $e\n$st');
    }
  }

  void addRoutine(RoutineItem item) {
    _routines.add(item);
    _recomputeCategoryCounts();
    notifyListeners();
    unawaited(_saveRoutinesList());
  }

  void upsertRoutine(RoutineItem item) {
    final i = _routines.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      _routines[i] = item;
    } else {
      _routines.add(item);
    }
    _recomputeCategoryCounts();
    notifyListeners();
    unawaited(_saveRoutinesList());
  }

  void removeRoutine(String id) {
    _routines.removeWhere((element) => element.id == id);
    _routineDoneDayKey.remove('rt_$id');
    _recomputeCategoryCounts();
    notifyListeners();
    unawaited(_saveRoutinesList());
    unawaited(_saveRoutineDonePrefs());
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
    applySyncHubResultsSelected(const [
      'REVIEW EMAIL FROM TEAM',
      'ORDER SUPPLIES FROM LIST',
      'FOLLOW UP CALENDAR INVITE',
      'SCHEDULE CHECKUP FROM NOTE',
    ]);
  }

  /// Add only selected Sync Hub suggestions (titles from review step).
  void applySyncHubResultsSelected(Iterable<String> selectedTitles) {
    final selected = selectedTitles.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (selected.isEmpty) return;
    final base = _demoToday;
    final suggestions = <({
      String categoryId,
      String categoryTag,
      String title,
      DateTime dueAt,
    })>[
      (
        categoryId: 'work',
        categoryTag: 'WORK',
        title: 'REVIEW EMAIL FROM TEAM',
        dueAt: base.add(const Duration(hours: 10)),
      ),
      (
        categoryId: 'shopping',
        categoryTag: 'SHOPPING',
        title: 'ORDER SUPPLIES FROM LIST',
        dueAt: base.add(const Duration(hours: 14)),
      ),
      (
        categoryId: 'general',
        categoryTag: 'GENERAL',
        title: 'FOLLOW UP CALENDAR INVITE',
        dueAt: base.add(const Duration(days: 1, hours: 9)),
      ),
      (
        categoryId: 'health',
        categoryTag: 'HEALTH',
        title: 'SCHEDULE CHECKUP FROM NOTE',
        dueAt: base.add(const Duration(days: 2, hours: 11)),
      ),
    ].where((s) => selected.contains(s.title)).toList();
    if (suggestions.isEmpty) return;

    if (_useConvex) {
      for (final s in suggestions) {
        unawaited(
          _convexCreate(
            categoryId: s.categoryId,
            categoryTag: s.categoryTag,
            title: s.title,
            dueAt: s.dueAt,
            isDone: false,
          ),
        );
      }
      return;
    }

    _idSeed += 1;
    for (var i = 0; i < suggestions.length; i++) {
      final s = suggestions[i];
      _tasks.add(
        BubbleTaskItem(
          id: 'sync_${_idSeed}_${i + 1}',
          categoryId: s.categoryId,
          categoryTag: s.categoryTag,
          title: s.title,
          dueAt: s.dueAt,
        ),
      );
    }
    _migrateAllTasksToCurrentPersona(persistConvex: false);
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
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
    final id = categoryId ?? _defaultTaskCategoryId();
    final tag = categoryTag ?? categoryTagForCategoryId(id);
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
    List<int>? reminderOffsets,
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
      final ro = _normalizeReminderOffsets(reminderOffsets);
      if (ro != null && ro.isNotEmpty) {
        args['reminderOffsets'] = ro;
      }
      await ConvexClient.instance.mutation(name: 'tasks:create', args: args);
      if (_useConvex) {
        unawaited(_convexHydrateTasksFromQuery());
      }
    } catch (e, st) {
      debugPrint('Convex create: $e\n$st');
    }
  }

  void updateTaskDue(String taskId, DateTime dueAt) {
    if (taskId.startsWith('rt_')) {
      final rid = taskId.replaceFirst('rt_', '');
      final i = _routines.indexWhere((e) => e.id == rid);
      if (i < 0) return;
      final hm = DateFormat('HH:mm').format(dueAt);
      _routines[i] = _routines[i].copyWith(
        startHour: dueAt.hour,
        startMinute: dueAt.minute,
        timeRange: hm,
      );
      notifyListeners();
      unawaited(_saveRoutinesList());
      return;
    }
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(dueAt: dueAt);
    if (_useConvex) {
      notifyListeners();
      unawaited(
        _convexUpdate(
          taskId,
          {'dueAtMs': dueAt.millisecondsSinceEpoch},
        ),
      );
      return;
    }
    _touchLocalTasks();
    notifyListeners();
  }

  void updateTaskTitle(String taskId, String title) {
    if (taskId.startsWith('rt_')) {
      final rid = taskId.replaceFirst('rt_', '');
      final i = _routines.indexWhere((e) => e.id == rid);
      if (i < 0) return;
      _routines[i] = _routines[i].copyWith(title: title.trim());
      notifyListeners();
      unawaited(_saveRoutinesList());
      return;
    }
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(title: title.toUpperCase());
    if (_useConvex) {
      notifyListeners();
      unawaited(_convexUpdate(taskId, {'title': title.toUpperCase()}));
      return;
    }
    _touchLocalTasks();
    notifyListeners();
  }

  void updateTaskRecurrence(String taskId, List<String>? recurrenceDays) {
    if (taskId.startsWith('rt_')) return;
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(recurrenceDays: recurrenceDays);
    if (_useConvex) {
      notifyListeners();
      if (recurrenceDays == null || recurrenceDays.isEmpty) {
        unawaited(
          _convexUpdate(taskId, {'clearRecurrence': true}),
        );
      } else {
        unawaited(_convexUpdate(taskId, {'recurrenceDays': recurrenceDays}));
      }
      return;
    }
    _touchLocalTasks();
    notifyListeners();
  }

  /// [offsets] — only 5, 30, 60 (minutes before due). Empty list clears reminders.
  void updateTaskReminderOffsets(String taskId, List<int> offsets) {
    if (taskId.startsWith('rt_')) return;
    final next = _normalizeReminderOffsets(offsets);
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(reminderOffsets: next);
    if (_useConvex) {
      notifyListeners();
      if (next == null || next.isEmpty) {
        unawaited(_convexUpdate(taskId, {'clearReminder': true}));
      } else {
        unawaited(_convexUpdate(taskId, {'reminderOffsets': next}));
      }
      return;
    }
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

  Future<bool> submitFeedback({
    required String contact,
    required bool preferPhone,
    required String message,
  }) async {
    if (!ConvexEnv.isConfigured || !ConvexEnv.backendReady) {
      return false;
    }
    try {
      await ConvexClient.instance.mutation(
        name: 'feedback:submit',
        args: {
          'contactType': preferPhone ? 'phone' : 'email',
          'contact': contact.trim(),
          'message': message.trim(),
          'languageCode': _languageCode,
        },
      );
      return true;
    } catch (e, st) {
      debugPrint('feedback:submit failed: $e\n$st');
      return false;
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

  String? _categoryTitleForTaskCategoryId(String categoryId) {
    for (final c in _categories) {
      if (c.id == categoryId) {
        return c.title;
      }
    }
    return null;
  }

  List<BubbleTaskItem> tasksForListView() {
    Iterable<BubbleTaskItem> list = _tasks;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) {
        if (t.title.toLowerCase().contains(q)) {
          return true;
        }
        if (t.categoryTag.toLowerCase().contains(q)) {
          return true;
        }
        final catTitle = _categoryTitleForTaskCategoryId(t.categoryId);
        if (catTitle != null && catTitle.toLowerCase().contains(q)) {
          return true;
        }
        final dueStr = formatDueLineCompact(t.dueAt).toLowerCase();
        if (dueStr.contains(q)) {
          return true;
        }
        return false;
      });
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
    if (_dailyRoutinesEnabled) {
      final today = DateTime.now();
      final dayKey = '${today.year}-${today.month}-${today.day}';
      for (final r in _routines) {
        final tid = 'rt_${r.id}';
        final doneToday = _routineDoneDayKey[tid] == dayKey;
        if (q.isNotEmpty && !r.title.toLowerCase().contains(q)) {
          continue;
        }
        switch (_listFilter) {
          case TaskListFilter.done:
            if (!doneToday) continue;
            break;
          case TaskListFilter.active:
            if (doneToday) continue;
            break;
          case TaskListFilter.all:
            break;
        }
        final due = DateTime(
          today.year,
          today.month,
          today.day,
          r.startHour,
          r.startMinute,
        );
        out.add(
          BubbleTaskItem(
            id: tid,
            categoryId: _defaultTaskCategoryId(),
            categoryTag: 'ROUTINE',
            title: r.title.toUpperCase(),
            dueAt: due,
            isDone: doneToday,
          ),
        );
      }
    }
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

  /// Задачи пузыря + сегодняшние рутины (если включены и пузырь совпадает с пузырём рутин).
  List<BubbleTaskItem> tasksForCategoryView(String categoryId) {
    final out = List<BubbleTaskItem>.from(tasksByCategory(categoryId));
    // Daily routines should be visible in every bubble view, not only "General".
    if (_dailyRoutinesEnabled) {
      final today = DateTime.now();
      final dayKey = '${today.year}-${today.month}-${today.day}';
      for (final r in _routines) {
        final tid = 'rt_${r.id}';
        final doneToday = _routineDoneDayKey[tid] == dayKey;
        final due = DateTime(
          today.year,
          today.month,
          today.day,
          r.startHour,
          r.startMinute,
        );
        out.add(
          BubbleTaskItem(
            id: tid,
            categoryId: _defaultTaskCategoryId(),
            categoryTag: 'ROUTINE',
            title: r.title.toUpperCase(),
            dueAt: due,
            isDone: doneToday,
          ),
        );
      }
    }
    out.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return out;
  }

  void toggleTaskDone(String taskId) {
    if (taskId.startsWith('rt_')) {
      final today = DateTime.now();
      final dayKey = '${today.year}-${today.month}-${today.day}';
      if (_routineDoneDayKey[taskId] == dayKey) {
        _routineDoneDayKey.remove(taskId);
      } else {
        _routineDoneDayKey[taskId] = dayKey;
      }
      _recomputeCategoryCounts();
      notifyListeners();
      unawaited(_saveRoutineDonePrefs());
      return;
    }
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final item = _tasks[index];
    final next = !item.isDone;
    if (_useConvex) {
      _tasks[index] = item.copyWith(isDone: next);
      _recomputeCategoryCounts();
      notifyListeners();
      unawaited(_convexUpdate(taskId, {'isDone': next}));
      return;
    }
    _tasks[index] = item.copyWith(isDone: next);
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
  }

  void deleteTask(String taskId) {
    if (taskId.startsWith('rt_')) {
      removeRoutine(taskId.replaceFirst('rt_', ''));
      return;
    }
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

  void _rebuildCategoriesFromPersona() {
    final slots = _slotsForPersona(_bubblePlannerPersona);
    _categories
      ..clear()
      ..addAll(
        slots.map(
          (s) => BubbleCategory(
            id: s.id,
            title: _titleForSlot(s),
            tasksCount: 0,
            color: s.color,
            position: s.position,
            size: s.size,
          ),
        ),
      );
  }

  void _migrateAllTasksToCurrentPersona({required bool persistConvex}) {
    for (var i = 0; i < _tasks.length; i++) {
      final t = _tasks[i];
      if (t.id.startsWith('rt_')) {
        continue;
      }
      final want = migrateCategoryIdToPersona(t.categoryId, _bubblePlannerPersona);
      final tag = categoryTagForCategoryId(want);
      if (t.categoryId == want && t.categoryTag == tag) {
        continue;
      }
      _tasks[i] = t.copyWith(categoryId: want, categoryTag: tag);
      if (persistConvex) {
        unawaited(
          _convexUpdate(
            t.id,
            {'categoryId': want, 'categoryTag': tag},
          ),
        );
      }
    }
  }

  Future<void> _syncPersonaFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = bubblePlannerPersonaFromStorage(
        prefs.getString(_kPrefsBubblePersona),
      );
      if (next != _bubblePlannerPersona) {
        _bubblePlannerPersona = next;
      }
      _rebuildCategoriesFromPersona();
      _migrateAllTasksToCurrentPersona(persistConvex: _useConvex);
      notifyListeners();
    } catch (e, st) {
      debugPrint('_syncPersonaFromDisk: $e\n$st');
    }
  }

  Future<void> setBubblePlannerPersona(BubblePlannerPersona value) async {
    if (value == _bubblePlannerPersona) {
      return;
    }
    _bubblePlannerPersona = value;
    _rebuildCategoriesFromPersona();
    _migrateAllTasksToCurrentPersona(persistConvex: _useConvex);
    _recomputeCategoryCounts();
    _touchLocalTasks();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsBubblePersona, value.name);
    } catch (e, st) {
      debugPrint('setBubblePlannerPersona: $e\n$st');
    }
  }

  void _recomputeCategoryCounts() {
    final baseSizeById = <String, double>{};
    for (final slot in _slotsForPersona(_bubblePlannerPersona)) {
      baseSizeById[slot.id] = slot.size;
    }

    for (var i = 0; i < _categories.length; i++) {
      final category = _categories[i];
      final count =
          _tasks.where((t) => t.categoryId == category.id && !t.isDone).length;
      final baseSize = baseSizeById[category.id] ?? category.size;
      // 0 задач => 1.0x (как сейчас), 10+ задач => 2.0x.
      final t = count.clamp(0, 10) / 10.0;
      final scaledSize = baseSize * (1 + t);
      _categories[i] = category.copyWith(tasksCount: count, size: scaledSize);
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
      case 'GROCERIES':
        return Icons.shopping_cart_outlined;
      case 'WORK':
      case 'STUDY':
      case 'PARTTIME':
        return Icons.work_outline_rounded;
      case 'HEALTH':
      case 'FAMILY_HEALTH':
        return Icons.favorite_border_rounded;
      case 'KIDS':
        return Icons.child_care_outlined;
      case 'SCHOOL':
        return Icons.school_outlined;
      case 'HOME':
        return Icons.home_outlined;
      case 'HOBBY':
        return Icons.palette_outlined;
      case 'SPORT':
        return Icons.fitness_center_rounded;
      case 'EXAMS':
        return Icons.assignment_outlined;
      case 'CAMPUS':
        return Icons.groups_outlined;
      case 'PERSONAL':
        return Icons.person_outline_rounded;
      case 'GENERAL':
        return Icons.inbox_outlined;
      case 'ROUTINE':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.inbox_outlined;
    }
  }

  String _tagFromParsedCategory(String category) {
    final id = _categoryIdByParsedCategory(category);
    return categoryTagForCategoryId(id);
  }

  String _categoryIdByParsedCategory(String category) {
    return categoryIdFromParsedLabel(category, _bubblePlannerPersona);
  }

  String _defaultTaskCategoryId() =>
      migrateCategoryIdToPersona('general', _bubblePlannerPersona);

  String _titleForSlot(BubbleSlotLayout slot) {
    if (slot.titleKey.startsWith('@')) {
      return slot.titleKey.substring(1);
    }
    return app_tr.tr(slot.titleKey, lang: _languageCode);
  }

  List<BubbleSlotLayout> _slotsForPersona(BubblePlannerPersona p) {
    final override = _personaSlotsOverride[p];
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return slotLayoutsForPersona(p);
  }

  Future<void> _loadPersonaSlotsPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsPersonaSlots);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final next = <BubblePlannerPersona, List<BubbleSlotLayout>>{};
      for (final entry in decoded.entries) {
        final persona = bubblePlannerPersonaFromStorage('${entry.key}');
        final value = entry.value;
        if (value is! List) continue;
        final slots = <BubbleSlotLayout>[];
        for (final it in value) {
          if (it is! Map) continue;
          final m = Map<String, dynamic>.from(it);
          slots.add(
            BubbleSlotLayout(
              id: '${m['id']}',
              titleKey: '${m['titleKey']}',
              color: Color((m['color'] as num?)?.toInt() ?? 0xFF9CA3AF),
              position: Offset(
                (m['x'] as num?)?.toDouble() ?? 0.5,
                (m['y'] as num?)?.toDouble() ?? 0.5,
              ),
              size: (m['size'] as num?)?.toDouble() ?? 112,
            ),
          );
        }
        if (slots.isNotEmpty) {
          next[persona] = slots;
        }
      }
      _personaSlotsOverride
        ..clear()
        ..addAll(next);
      _rebuildCategoriesFromPersona();
      _recomputeCategoryCounts();
      notifyListeners();
    } catch (e, st) {
      debugPrint('_loadPersonaSlotsPrefs: $e\n$st');
    }
  }

  Future<void> _savePersonaSlotsPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{};
      for (final e in _personaSlotsOverride.entries) {
        payload[e.key.name] = e.value
            .map((s) => {
                  'id': s.id,
                  'titleKey': s.titleKey,
                  'color': s.color.toARGB32(),
                  'x': s.position.dx,
                  'y': s.position.dy,
                  'size': s.size,
                })
            .toList();
      }
      await prefs.setString(_kPrefsPersonaSlots, jsonEncode(payload));
    } catch (e, st) {
      debugPrint('_savePersonaSlotsPrefs: $e\n$st');
    }
  }

  List<BubbleCategory> categoryManagerList(BubblePlannerPersona persona) {
    final slots = _slotsForPersona(persona);
    return slots
        .map(
          (s) => BubbleCategory(
            id: s.id,
            title: _titleForSlot(s),
            tasksCount: _tasks.where((t) => t.categoryId == s.id && !t.isDone).length,
            color: s.color,
            position: s.position,
            size: s.size,
          ),
        )
        .toList();
  }

  Future<void> addCategoryForPersona(BubblePlannerPersona persona, String title) async {
    final name = title.trim();
    if (name.isEmpty) return;
    final base = List<BubbleSlotLayout>.from(_slotsForPersona(persona));
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final rnd = Random(id.hashCode);
    base.add(
      BubbleSlotLayout(
        id: id,
        titleKey: '@$name',
        color: Color(0xFF66BB6A + rnd.nextInt(0x00777777)).withAlpha(0xFF),
        position: Offset(0.2 + rnd.nextDouble() * 0.6, 0.2 + rnd.nextDouble() * 0.6),
        size: 102 + rnd.nextDouble() * 24,
      ),
    );
    _personaSlotsOverride[persona] = base;
    if (persona == _bubblePlannerPersona) {
      _rebuildCategoriesFromPersona();
      _recomputeCategoryCounts();
      notifyListeners();
    }
    await _savePersonaSlotsPrefs();
  }

  Future<void> renameCategoryForPersona(
    BubblePlannerPersona persona,
    String categoryId,
    String newTitle,
  ) async {
    final name = newTitle.trim();
    if (name.isEmpty) return;
    final slots = List<BubbleSlotLayout>.from(_slotsForPersona(persona));
    final i = slots.indexWhere((s) => s.id == categoryId);
    if (i < 0) return;
    final cur = slots[i];
    slots[i] = BubbleSlotLayout(
      id: cur.id,
      titleKey: '@$name',
      color: cur.color,
      position: cur.position,
      size: cur.size,
    );
    _personaSlotsOverride[persona] = slots;
    if (persona == _bubblePlannerPersona) {
      _rebuildCategoriesFromPersona();
      notifyListeners();
    }
    await _savePersonaSlotsPrefs();
  }

  Future<void> deleteCategoryForPersona(
    BubblePlannerPersona persona,
    String categoryId,
  ) async {
    final slots = List<BubbleSlotLayout>.from(_slotsForPersona(persona));
    if (slots.length <= 1) return;
    final before = slots.length;
    slots.removeWhere((s) => s.id == categoryId);
    if (slots.length == before) return;
    _personaSlotsOverride[persona] = slots;
    if (persona == _bubblePlannerPersona) {
      final fallback = slots.first.id;
      for (var i = 0; i < _tasks.length; i++) {
        if (_tasks[i].categoryId != categoryId) continue;
        _tasks[i] = _tasks[i].copyWith(
          categoryId: fallback,
          categoryTag: categoryTagForCategoryId(fallback),
        );
      }
      _rebuildCategoriesFromPersona();
      _recomputeCategoryCounts();
      _touchLocalTasks();
      notifyListeners();
    }
    await _savePersonaSlotsPrefs();
  }
}

double bubbleFloatDurationMs(String categoryId) {
  final seed = categoryId.hashCode.abs();
  return (4800 + Random(seed).nextInt(2400)).toDouble();
}
