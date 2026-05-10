import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_state.dart';
import 'convex_env.dart';
import 'app_theme.dart';
import 'translations.dart' show tr, trFill;
import 'services/paper_scan.dart';
import 'services/voice_input_errors.dart';
import 'screens/login_screen.dart';
import 'tabs/tasks_list_tab.dart';
import 'widgets/bubble_widget.dart';
import 'widgets/confirm_task_sheet.dart';
import 'widgets/notes_sheet.dart';
import 'widgets/planner_settings_sheet.dart';
import 'widgets/sticky_note_add_task_sheet.dart';
import 'widgets/pomodoro_sheet.dart';
import 'widgets/sync_hub_sheet.dart';
import 'widgets/movable_add_fab.dart';
import 'widgets/reminder_banner_layer.dart';
import 'widgets/task_share_sheets.dart';
import 'widgets/unified_task_row.dart';
import 'planner_languages.dart' show kPlannerLanguageCodes;

/// Сантиметры → логические px по короткой стороне экрана (~6.5 см типичная ширина контента в руке).
double _talkScreenCm(BuildContext context, double cm) {
  final s = MediaQuery.sizeOf(context).shortestSide;
  return s * (cm / 6.5);
}

/// [num.clamp] throws if lower > upper; web/narrow layouts can also produce NaN.
double _safeClampDouble(double value, double minBound, double maxBound) {
  var lo = minBound;
  var hi = maxBound;
  if (!lo.isFinite) lo = 0;
  if (!hi.isFinite) hi = lo;
  if (lo > hi) {
    final t = lo;
    lo = hi;
    hi = t;
  }
  if (!value.isFinite) return lo;
  return value.clamp(lo, hi);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final loc in kPlannerLanguageCodes) {
    try {
      await initializeDateFormatting(loc);
    } catch (e, st) {
      debugPrint('initializeDateFormatting($loc): $e\n$st');
    }
  }
  if (kIsWeb) {
    debugPrint(
      'Bubble Planner web: для сохранения demo-задач после обновления страницы '
      'запускайте с фиксированным портом, например: '
      'flutter run -d chrome --web-port=8080 --dart-define-from-file=config/dart_defines/dev.json '
      '(в VS Code уже задано в .vscode/launch.json).',
    );
  }
  if (ConvexEnv.isConfigured) {
    try {
      debugPrint('Convex ENV=${ConvexEnv.env} URL=${ConvexEnv.deploymentUrl}');
      await ConvexClient.initialize(
        ConvexConfig(
          deploymentUrl: ConvexEnv.deploymentUrl,
          clientId: 'bubble-planner',
          operationTimeout: const Duration(seconds: 60),
          healthCheckQuery: 'health:ping',
        ),
      );
      ConvexEnv.backendReady = true;
    } catch (e, st) {
      debugPrint('ConvexClient.initialize failed: $e\n$st');
      ConvexEnv.backendReady = false;
    }
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const BubblePlannerApp(),
    ),
  );
}

class BubblePlannerApp extends StatefulWidget {
  const BubblePlannerApp({super.key});

  @override
  State<BubblePlannerApp> createState() => _BubblePlannerAppState();
}

class _BubblePlannerAppState extends State<BubblePlannerApp>
    with WidgetsBindingObserver {
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState ??= context.read<AppState>();
  }

  @override
  void dispose() {
    unawaited(_appState?.persistLocalTasksNow());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_appState?.persistLocalTasksNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = BubblePlannerColors.fromId(state.colorPaletteId);
    final lightPalette =
        palette.brightness == Brightness.light ? palette : BubblePlannerColors.wellnessMint;
    final darkPalette =
        palette.brightness == Brightness.dark ? palette : BubblePlannerColors.classic;
    final themeMode = switch (state.themeMode) {
      BubbleThemeMode.system => ThemeMode.system,
      BubbleThemeMode.light => ThemeMode.light,
      BubbleThemeMode.dark => ThemeMode.dark,
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bubble Planner',
      locale: Locale(state.languageCode),
      theme: AppTheme.forPalette(state.fontChoice, lightPalette),
      darkTheme: AppTheme.forPalette(state.fontChoice, darkPalette),
      themeMode: themeMode,
      home: state.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  Offset _parallax = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = <Widget>[
      _TalkPage(onSearchTap: () => setState(() => _currentIndex = 2)),
      _BubblesPage(
        parallax: _parallax,
        onParallax: (value) => setState(() => _parallax = value),
        onSearchTap: () => setState(() => _currentIndex = 2),
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
      const TasksListTab(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          const _GradientBackground(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: pages[_currentIndex],
            ),
          ),
          const ReminderBannerLayer(),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onChanged: (index) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
        onToolsTap: () {
          final lang = state.languageCode;
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) {
              final bp = ctx.bp;
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: bp.modalSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: bp.modalBorder),
                  boxShadow: [
                    BoxShadow(
                      color: bp.navShadow,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            tr('footerToolsLabel', lang: lang),
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                  color: bp.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close_rounded, color: bp.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _PrimaryToolRow(
                        icon: Icons.sticky_note_2_outlined,
                        title: tr('notesFooterLabel', lang: lang),
                        subtitle: tr('notesTitle', lang: lang),
                        accent: bp.toolAccentNotes,
                        onTap: () {
                          Navigator.pop(ctx);
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const NotesSheet(),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _PrimaryToolRow(
                        iconWidget: const PomodoroTomatoIcon(size: 26),
                        title: tr('pomodoroFooterLabel', lang: lang),
                        subtitle: tr('pomodoroTitle', lang: lang),
                        accent: bp.toolAccentPomodoro,
                        onTap: () {
                          Navigator.pop(ctx);
                          PomodoroHomeButton.open(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BubblesPage extends StatelessWidget {
  const _BubblesPage({
    required this.parallax,
    required this.onParallax,
    required this.onSearchTap,
    required this.onNavigateTab,
  });

  final Offset parallax;
  final ValueChanged<Offset> onParallax;
  final VoidCallback onSearchTap;
  final ValueChanged<int> onNavigateTab;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.categories;
    final lang = state.languageCode;
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: Row(
            children: [
              Text(
                tr('bubblesPageTitle', lang: lang),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Spacer(),
              _GlassIconButton(
                icon: Icons.search_rounded,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSearchTap();
                },
              ),
              const SizedBox(width: 10),
              _GlassIconButton(
                icon: state.themeMode == BubbleThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final next = state.themeMode == BubbleThemeMode.dark
                      ? BubbleThemeMode.light
                      : BubbleThemeMode.dark;
                  context.read<AppState>().setThemeMode(next);
                },
              ),
              const SizedBox(width: 10),
              _GlassIconButton(
                icon: Icons.settings_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showPlannerSettings(context);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onPanUpdate: (details) {
              final dx = (details.localPosition.dx / size.width - 0.5) * 8;
              final dy = (details.localPosition.dy / size.height - 0.5) * 10;
              onParallax(Offset(dx, dy));
            },
            onPanEnd: (_) => onParallax(Offset.zero),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    for (final item in categories)
                      BubbleWidget(
                        category: item.copyWith(
                          position: Offset(
                            item.position.dx * constraints.maxWidth -
                                item.size / 2,
                            item.position.dy * constraints.maxHeight -
                                item.size / 2,
                          ),
                        ),
                        parallaxOffset: parallax,
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              transitionDuration:
                                  const Duration(milliseconds: 330),
                              pageBuilder: (_, animation, __) => FadeTransition(
                                opacity: animation,
                                child: CategoryTasksScreen(
                                  category: item,
                                  onNavigateTab: (index) {
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    onNavigateTab(index);
                                  },
                                  onToolsTap: () {
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    Future<void>.delayed(
                                      const Duration(milliseconds: 120),
                                      () {
                                        if (!context.mounted) return;
                                        final lang = state.languageCode;
                                        showModalBottomSheet<void>(
                                          context: context,
                                          backgroundColor: Colors.transparent,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(20)),
                                          ),
                                          builder: (ctx) {
                                            final bp = ctx.bp;
                                            return Container(
                                              margin:
                                                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                              padding:
                                                  const EdgeInsets.fromLTRB(14, 12, 14, 14),
                                              decoration: BoxDecoration(
                                                color: bp.modalSurface,
                                                borderRadius: BorderRadius.circular(24),
                                                border: Border.all(color: bp.modalBorder),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: bp.navShadow,
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: SafeArea(
                                                top: false,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.stretch,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          tr('footerToolsLabel', lang: lang),
                                                          style: Theme.of(ctx)
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                                color: bp.textPrimary,
                                                                fontWeight:
                                                                    FontWeight.w800,
                                                              ),
                                                        ),
                                                        const Spacer(),
                                                        IconButton(
                                                          onPressed: () => Navigator.pop(ctx),
                                                          icon: Icon(Icons.close_rounded,
                                                              color: bp.textSecondary),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    _PrimaryToolRow(
                                                      icon: Icons.sticky_note_2_outlined,
                                                      title:
                                                          tr('notesFooterLabel', lang: lang),
                                                      subtitle: tr('notesTitle', lang: lang),
                                                      accent: bp.toolAccentNotes,
                                                      onTap: () {
                                                        Navigator.pop(ctx);
                                                        showModalBottomSheet<void>(
                                                          context: context,
                                                          isScrollControlled: true,
                                                          backgroundColor:
                                                              Colors.transparent,
                                                          builder: (_) =>
                                                              const NotesSheet(),
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(height: 10),
                                                    _PrimaryToolRow(
                                                      iconWidget:
                                                          const PomodoroTomatoIcon(size: 26),
                                                      title: tr('pomodoroFooterLabel',
                                                          lang: lang),
                                                      subtitle:
                                                          tr('pomodoroTitle', lang: lang),
                                                      accent: bp.toolAccentPomodoro,
                                                      onTap: () {
                                                        Navigator.pop(ctx);
                                                        PomodoroHomeButton.open(context);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class CategoryTasksScreen extends StatefulWidget {
  const CategoryTasksScreen({
    super.key,
    required this.category,
    required this.onNavigateTab,
    required this.onToolsTap,
  });

  final BubbleCategory category;
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onToolsTap;

  @override
  State<CategoryTasksScreen> createState() => _CategoryTasksScreenState();
}

class _CategoryTasksScreenState extends State<CategoryTasksScreen> {
  String? _menuOpenTaskId;
  bool _bulkMode = false;
  bool _searchExpanded = false;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  BubbleThemeMode _nextThemeMode(AppState state) {
    if (state.themeMode == BubbleThemeMode.system) {
      final isDarkNow = Theme.of(context).brightness == Brightness.dark;
      return isDarkNow ? BubbleThemeMode.light : BubbleThemeMode.dark;
    }
    return state.themeMode == BubbleThemeMode.dark
        ? BubbleThemeMode.light
        : BubbleThemeMode.dark;
  }

  void _openStickyAdd(BuildContext context) {
    showStickyNoteAddTaskSheet(context);
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bp = context.bp;
    final category = widget.category;
    final allTasks = state.tasksForCategoryView(category.id);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayTasks =
        allTasks.where((t) => state.isSameCalendarDay(t.dueAt, todayStart)).toList();
    final futureTasks =
        allTasks.where((t) => state.isFutureCalendarDayTask(t, todayStart)).toList();
    final earlierPastDone = allTasks.where((t) {
      if (t.id.startsWith('rt_')) return false;
      return state.calendarDayStart(t.dueAt).isBefore(todayStart) && t.isDone;
    }).toList();
    final attentionTasks =
        allTasks.where((t) => state.isAttentionOverdueTask(t, todayStart)).toList();
    final query = _search.text.trim().toLowerCase();
    bool matchesQuery(BubbleTaskItem task) {
      if (query.isEmpty) return true;
      final due = state.formatDueLineCompact(task.dueAt).toLowerCase();
      return task.title.toLowerCase().contains(query) ||
          task.categoryTag.toLowerCase().contains(query) ||
          due.contains(query);
    }
    final filteredToday = todayTasks.where(matchesQuery).toList();
    final filteredFuture = futureTasks.where(matchesQuery).toList();
    final filteredEarlier = earlierPastDone.where(matchesQuery).toList();
    final filteredAttention = attentionTasks.where(matchesQuery).toList();
    final visibleTasks = [
      ...filteredToday,
      ...filteredFuture,
      ...filteredEarlier,
      ...filteredAttention,
    ];
    const attentionAccent = Color(0xFFFF6D4A);
    final categoryUniverse = allTasks.map((e) => e.id).toSet();
    final selectedInCategory =
        state.selectedTaskIds.where(categoryUniverse.contains).length;
    final bulkBarVisible = _bulkMode && selectedInCategory > 0;

    final titleOnCard = bp.textPrimary;
    final routinesBg = bp.warning.withValues(alpha: 0.14);
    final routinesBorder = bp.warning.withValues(alpha: 0.35);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: bp.taskSheetGradient,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    decoration: BoxDecoration(
                      color: bp.taskCardBg,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: bp.brightness == Brightness.light
                          ? [
                              BoxShadow(
                                color: bp.navShadow,
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                          child: Row(
                            children: [
                              Tooltip(
                                message: tr('navBackToBubbles', lang: state.languageCode),
                                child: _IconAction(
                                  icon: Icons.arrow_back_rounded,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${category.title} (${allTasks.length})',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: titleOnCard,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              _IconAction(
                                icon: Icons.settings_rounded,
                                onTap: () => showPlannerSettings(context),
                              ),
                              _IconAction(
                                icon: Icons.search,
                                onTap: () {
                                  setState(() {
                                    _searchExpanded = !_searchExpanded;
                                    if (_searchExpanded) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (!mounted) return;
                                        _searchFocus.requestFocus();
                                      });
                                    } else {
                                      _searchFocus.unfocus();
                                      _search.clear();
                                    }
                                  });
                                },
                              ),
                              _IconAction(
                                icon: state.themeMode == BubbleThemeMode.dark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  final next = _nextThemeMode(state);
                                  context.read<AppState>().setThemeMode(next);
                                  setState(() {});
                                },
                              ),
                              _IconAction(
                                icon: Icons.share_outlined,
                                onTap: () async {
                                  await runTasksListShareFlow(
                                    context,
                                    setBulkMode: (b) => setState(() => _bulkMode = b),
                                    universeIds: categoryUniverse,
                                    allowPickWithCheckmarks: true,
                                    allLabelKey: 'shareAllTasks',
                                  );
                                },
                              ),
                              _IconAction(
                                icon: Icons.delete_outline_rounded,
                                onTap: () async {
                                  await runTasksListDeleteFlow(
                                    context,
                                    setBulkMode: (b) => setState(() => _bulkMode = b),
                                    universeIds: categoryUniverse,
                                    allowPickWithCheckmarks: true,
                                    allLabelKey: 'shareAllTasks',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        if (_searchExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                            child: TextField(
                              controller: _search,
                              focusNode: _searchFocus,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: bp.textPrimary),
                              decoration: InputDecoration(
                                hintText: tr('searchPlaceholder', lang: state.languageCode),
                                hintStyle:
                                    TextStyle(color: bp.textSecondary.withValues(alpha: 0.72)),
                                prefixIcon: Icon(Icons.search_rounded, color: bp.textSecondary),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () => setState(() => _search.clear()),
                                        icon: Icon(Icons.close_rounded, color: bp.textSecondary),
                                      ),
                                filled: true,
                                fillColor: bp.listCardFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(color: bp.listCardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(color: bp.listCardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(color: bp.primary.withValues(alpha: 0.85)),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: routinesBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: routinesBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wb_sunny_outlined, color: bp.warning),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tr('enableDailyRoutinesBanner', lang: state.languageCode),
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: bp.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: state.dailyRoutinesEnabled,
                                  onChanged: (v) {
                                    HapticFeedback.selectionClick();
                                    context.read<AppState>().toggleDailyRoutines(v);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (_menuOpenTaskId != null &&
                                  (n is ScrollUpdateNotification ||
                                      n is UserScrollNotification)) {
                                setState(() => _menuOpenTaskId = null);
                              }
                              return false;
                            },
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                              children: [
                                if (filteredToday.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      _CategorySectionLabel(
                                        text: tr('todaySection', lang: state.languageCode),
                                        accent: bp.warning,
                                      ),
                                      const Spacer(),
                                      if (_bulkMode)
                                        TextButton(
                                          onPressed: () => state
                                              .selectAllVisible(filteredToday.map((e) => e.id)),
                                          child: Text(
                                            tr('selectAll', lang: state.languageCode),
                                            style: TextStyle(color: bp.primary),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  for (final task in filteredToday)
                                    UnifiedTaskRow(
                                      task: task,
                                      menuOpen: _menuOpenTaskId == task.id,
                                      bulkMode: _bulkMode,
                                      selectedInBulk:
                                          state.selectedTaskIds.contains(task.id),
                                      onLightTaskPanel: false,
                                      onBulkModeForSheets: (b) =>
                                          setState(() => _bulkMode = b),
                                      sheetUniverseTaskIds: categoryUniverse,
                                      sheetAllLabelKey: 'shareAllTasks',
                                      onMenuTap: () {
                                        if (_menuOpenTaskId == task.id) {
                                          setState(() => _menuOpenTaskId = null);
                                        } else {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            setState(() => _menuOpenTaskId = task.id);
                                          });
                                        }
                                      },
                                      onCheckTap: () {
                                        final app = context.read<AppState>();
                                        if (_bulkMode) {
                                          app.toggleTaskSelection(task.id);
                                        } else {
                                          app.toggleTaskDone(task.id);
                                        }
                                      },
                                      onQuickActionDone: () =>
                                          setState(() => _menuOpenTaskId = null),
                                    ),
                                ],
                                if (filteredFuture.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      _CategorySectionLabel(
                                        text: tr('followingDaysSection', lang: state.languageCode),
                                        accent: bp.warning,
                                      ),
                                      const Spacer(),
                                      if (_bulkMode)
                                        TextButton(
                                          onPressed: () => state
                                              .selectAllVisible(filteredFuture.map((e) => e.id)),
                                          child: Text(
                                            tr('selectAll', lang: state.languageCode),
                                            style: TextStyle(color: bp.primary),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  for (final task in filteredFuture)
                                    UnifiedTaskRow(
                                      task: task,
                                      menuOpen: _menuOpenTaskId == task.id,
                                      bulkMode: _bulkMode,
                                      selectedInBulk:
                                          state.selectedTaskIds.contains(task.id),
                                      onLightTaskPanel: false,
                                      onBulkModeForSheets: (b) =>
                                          setState(() => _bulkMode = b),
                                      sheetUniverseTaskIds: categoryUniverse,
                                      sheetAllLabelKey: 'shareAllTasks',
                                      onMenuTap: () {
                                        if (_menuOpenTaskId == task.id) {
                                          setState(() => _menuOpenTaskId = null);
                                        } else {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            setState(() => _menuOpenTaskId = task.id);
                                          });
                                        }
                                      },
                                      onCheckTap: () {
                                        final app = context.read<AppState>();
                                        if (_bulkMode) {
                                          app.toggleTaskSelection(task.id);
                                        } else {
                                          app.toggleTaskDone(task.id);
                                        }
                                      },
                                      onQuickActionDone: () =>
                                          setState(() => _menuOpenTaskId = null),
                                    ),
                                ],
                                if (filteredAttention.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      _CategorySectionLabel(
                                        text: tr('needsAttentionSection', lang: state.languageCode),
                                        accent: attentionAccent,
                                      ),
                                      const Spacer(),
                                      if (_bulkMode)
                                        TextButton(
                                          onPressed: () => state
                                              .selectAllVisible(filteredAttention.map((e) => e.id)),
                                          child: Text(
                                            tr('selectAll', lang: state.languageCode),
                                            style: TextStyle(color: bp.primary),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  for (final task in filteredAttention)
                                    UnifiedTaskRow(
                                      task: task,
                                      menuOpen: _menuOpenTaskId == task.id,
                                      bulkMode: _bulkMode,
                                      selectedInBulk:
                                          state.selectedTaskIds.contains(task.id),
                                      onLightTaskPanel: false,
                                      attentionHighlight: true,
                                      onBulkModeForSheets: (b) =>
                                          setState(() => _bulkMode = b),
                                      sheetUniverseTaskIds: categoryUniverse,
                                      sheetAllLabelKey: 'shareAllTasks',
                                      onMenuTap: () {
                                        if (_menuOpenTaskId == task.id) {
                                          setState(() => _menuOpenTaskId = null);
                                        } else {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            setState(() => _menuOpenTaskId = task.id);
                                          });
                                        }
                                      },
                                      onCheckTap: () {
                                        final app = context.read<AppState>();
                                        if (_bulkMode) {
                                          app.toggleTaskSelection(task.id);
                                        } else {
                                          app.toggleTaskDone(task.id);
                                        }
                                      },
                                      onQuickActionDone: () =>
                                          setState(() => _menuOpenTaskId = null),
                                    ),
                                ],
                                if (filteredEarlier.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      _CategorySectionLabel(
                                        text: tr('earlierSection', lang: state.languageCode),
                                        accent: bp.warning,
                                      ),
                                      const Spacer(),
                                      if (_bulkMode)
                                        TextButton(
                                          onPressed: () => state
                                              .selectAllVisible(filteredEarlier.map((e) => e.id)),
                                          child: Text(
                                            tr('selectAll', lang: state.languageCode),
                                            style: TextStyle(color: bp.primary),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  for (final task in filteredEarlier)
                                    UnifiedTaskRow(
                                      task: task,
                                      menuOpen: _menuOpenTaskId == task.id,
                                      bulkMode: _bulkMode,
                                      selectedInBulk:
                                          state.selectedTaskIds.contains(task.id),
                                      onLightTaskPanel: false,
                                      onBulkModeForSheets: (b) =>
                                          setState(() => _bulkMode = b),
                                      sheetUniverseTaskIds: categoryUniverse,
                                      sheetAllLabelKey: 'shareAllTasks',
                                      onMenuTap: () {
                                        if (_menuOpenTaskId == task.id) {
                                          setState(() => _menuOpenTaskId = null);
                                        } else {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            setState(() => _menuOpenTaskId = task.id);
                                          });
                                        }
                                      },
                                      onCheckTap: () {
                                        final app = context.read<AppState>();
                                        if (_bulkMode) {
                                          app.toggleTaskSelection(task.id);
                                        } else {
                                          app.toggleTaskDone(task.id);
                                        }
                                      },
                                      onQuickActionDone: () =>
                                          setState(() => _menuOpenTaskId = null),
                                    ),
                                ],
                                if (visibleTasks.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Text(
                                      tr('noTasks', lang: state.languageCode),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: titleOnCard.withValues(alpha: 0.55),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          MovableAddFab(
            storageKey: 'category_tasks_bottom_right',
            onPressed: () => _openStickyAdd(context),
            accent: bp.primary,
            onPrimary: bp.onPrimary,
            minBottom: 22 + MediaQuery.paddingOf(context).bottom,
            bottomReserved: bulkBarVisible ? 138 : 0,
          ),
          if (bulkBarVisible)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final ids =
                            state.selectedTaskIds.where(categoryUniverse.contains).toList();
                        final txt = state.shareTextForTasks(ids);
                        if (txt.isEmpty) return;
                        final ch = await showShareChannelSheet(context);
                        if (!context.mounted || ch == null) return;
                        await dispatchTaskShare(context, ch, txt);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: bp.primary,
                        foregroundColor: bp.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: Icon(Icons.ios_share_rounded, size: 20, color: bp.onPrimary),
                      label: Text(
                        trFill(
                          'shareSelected',
                          {'n': '$selectedInCategory'},
                          lang: state.languageCode,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: () {
                        final ids =
                            state.selectedTaskIds.where(categoryUniverse.contains).toList();
                        state.deleteTasksByIds(ids);
                        state.clearSelection();
                        setState(() => _bulkMode = false);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB42318),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: Text(
                        '${tr('delete', lang: state.languageCode)} ($selectedInCategory)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () {
                        state.clearSelection();
                        setState(() => _bulkMode = false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: bp.textPrimary,
                        side: BorderSide(color: bp.listCardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(tr('cancelSelection', lang: state.languageCode)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: 1,
        onChanged: widget.onNavigateTab,
        onToolsTap: widget.onToolsTap,
      ),
    );
  }
}

class _CategorySectionLabel extends StatelessWidget {
  const _CategorySectionLabel({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.85,
          fontSize: 8.5,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    final iconColor = bp.textSecondary;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: iconColor),
      splashRadius: 20,
    );
  }
}

class _TalkPage extends StatefulWidget {
  const _TalkPage({required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  State<_TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<_TalkPage> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _capturedEdit = TextEditingController();
  bool _isListening = false;
  String _capturedText = '';
  List<_SpokenWordEntry> _spokenWordEntries = const [];
  int _nextSpokenWordId = 1;

  @override
  void dispose() {
    _speech.stop();
    _capturedEdit.dispose();
    super.dispose();
  }

  List<String> _tokenizeWords(String text) {
    return text
        .trim()
        .split(RegExp(r'[\s,.;:!?()]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _startsWithWords(List<String> whole, List<String> prefix) {
    if (prefix.length > whole.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (whole[i].toLowerCase() != prefix[i].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  void _syncWordBubbles(String recognizedWords) {
    final next = _tokenizeWords(recognizedWords);
    if (next.isEmpty) {
      setState(() {
        _capturedText = recognizedWords;
        _spokenWordEntries = const [];
      });
      return;
    }
    final currentWords = _spokenWordEntries.map((e) => e.word).toList();
    if (_startsWithWords(next, currentWords)) {
      if (next.length == currentWords.length) {
        setState(() => _capturedText = recognizedWords);
        return;
      }
      final appended = <_SpokenWordEntry>[];
      for (var i = currentWords.length; i < next.length; i++) {
        appended.add(_SpokenWordEntry(id: _nextSpokenWordId++, word: next[i]));
      }
      setState(() {
        _capturedText = recognizedWords;
        _spokenWordEntries = [..._spokenWordEntries, ...appended];
      });
      return;
    }
    final rebuilt = <_SpokenWordEntry>[];
    for (final word in next) {
      rebuilt.add(_SpokenWordEntry(id: _nextSpokenWordId++, word: word));
    }
    setState(() {
      _capturedText = recognizedWords;
      _spokenWordEntries = rebuilt;
    });
  }

  Future<bool> _openConfirmSheet({String initial = ''}) async {
    if (!mounted) return false;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConfirmTaskSheet(initialTitle: initial),
    );
    return added == true;
  }

  /// Сканирование бумажной записи (камера/галерея → OCR на Android/iOS).
  Future<void> _scanPaperAndOpenConfirm() async {
    HapticFeedback.lightImpact();
    final text = await scanTextFromPaper(context);
    if (!mounted) return;
    if (text == null) return;
    final title = _scanToTaskTitle(text);
    if (title.isEmpty) return;
    await _openConfirmSheet(initial: title);
  }

  Future<void> _toggleVoiceInput() async {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    final lang = context.read<AppState>().languageCode;
    final available = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(voiceInputErrorSnackText(error.errorMsg, lang)),
          ),
        );
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice input is unavailable in this browser/device. Try Chrome on Android or use keyboard input.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _capturedText = '';
      _capturedEdit.text = '';
      _isListening = true;
      _spokenWordEntries = const [];
    });
    await _speech.listen(
      onResult: (result) {
        _syncWordBubbles(result.recognizedWords);
        _capturedEdit.value = TextEditingValue(
          text: _capturedText,
          selection: TextSelection.collapsed(offset: _capturedText.length),
        );
      },
    );
  }

  Future<void> _continueWithCapturedText() async {
    final text = _capturedEdit.text.trim();
    if (text.isEmpty) return;
    final added = await _openConfirmSheet(initial: text);
    if (added && mounted) {
      setState(() {
        _capturedText = '';
        _capturedEdit.clear();
        _spokenWordEntries = const [];
      });
    }
  }

  void _openSyncHub() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SyncHubSheet(),
    );
  }

  BubbleThemeMode _nextThemeMode(AppState state) {
    if (state.themeMode == BubbleThemeMode.system) {
      final isDarkNow = Theme.of(context).brightness == Brightness.dark;
      return isDarkNow ? BubbleThemeMode.light : BubbleThemeMode.dark;
    }
    return state.themeMode == BubbleThemeMode.dark
        ? BubbleThemeMode.light
        : BubbleThemeMode.dark;
  }

  String _scanToTaskTitle(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ');
    if (normalized.length <= 140) return normalized;
    return '${normalized.substring(0, 140).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.languageCode;
    final bp = context.bp;
    final accent = bp.talkAccent;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewH = constraints.maxHeight;
        // Нижний блок с микрофоном не должен выталкивать колонку: на низком окне (web) уменьшаем высоту.
        final micH = math.min(340.0, math.max(120.0, viewH * 0.5));

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      _GlassIconButton(
                        icon: Icons.search_rounded,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onSearchTap();
                        },
                      ),
                      const SizedBox(width: 10),
                      _GlassIconButton(
                        icon: state.themeMode == BubbleThemeMode.dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          final next = _nextThemeMode(state);
                          context.read<AppState>().setThemeMode(next);
                        },
                      ),
                      const SizedBox(width: 10),
                      _GlassIconButton(
                        icon: Icons.settings_rounded,
                        onTap: () {
                          showPlannerSettings(context);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, micH + safeBottom + 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _BrandMark(),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'ubble',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: bp.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 22,
                                        ),
                                  ),
                                  TextSpan(
                                    text: 'Planner',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: accent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 22,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr('readyForTasks', lang: lang),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: bp.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isListening ? tr('listeningHint', lang: lang) : tr('tapToTalk', lang: lang),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: bp.textSecondary,
                              ),
                        ),
                        if (_isListening && _spokenWordEntries.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _SpokenWordsBubbles(
                            entries: _spokenWordEntries,
                          ),
                        ],
                        if (!_isListening && _capturedText.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: bp.listCardFill.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: bp.listCardBorder),
                            ),
                            child: TextField(
                              controller: _capturedEdit,
                              minLines: 1,
                              maxLines: 2,
                              style: TextStyle(color: bp.textPrimary),
                              decoration: InputDecoration(
                                hintText: tr('typeYourTaskHint', lang: lang),
                                hintStyle: TextStyle(
                                  color: bp.textSecondary.withValues(alpha: 0.75),
                                ),
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  tooltip: tr('okAddTask', lang: lang),
                                  onPressed: _continueWithCapturedText,
                                  icon: Icon(Icons.send_rounded, color: bp.primary),
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _continueWithCapturedText(),
                              onChanged: (v) => _capturedText = v,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _WelcomeProfileRow(),
                        SizedBox(height: 24 + safeBottom),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Микрофон и меню: поверх контента, чтобы не было overflow на низком экране.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(bottom: 6 + safeBottom),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const micHit = _TalkMicThumbButton.hitSize;
                    const marginRight = 120.0;
                    final gapFromMic = _talkScreenCm(context, 2.0);
                    const menuThickness = 56.0;
                    final stackH = micH;
                    final mqW = MediaQuery.sizeOf(context).width;
                    final w = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : mqW;
                    final cx = w - marginRight - micHit / 2;
                    final cy = stackH / 2;
                    var menuOuterRadius = micHit / 2 + gapFromMic + menuThickness;
                    final maxDiameter = math.max(80.0, math.min(w - 12, stackH - 12));
                    final maxOuterR = maxDiameter / 2;
                    const minOuterR = menuThickness + 8;
                    if (minOuterR <= maxOuterR) {
                      menuOuterRadius = _safeClampDouble(menuOuterRadius, minOuterR, maxOuterR);
                    } else {
                      menuOuterRadius = maxOuterR;
                    }
                    var menuStroke = menuThickness;
                    final maxStroke = math.max(6.0, menuOuterRadius - 8);
                    if (menuStroke > maxStroke) {
                      menuStroke = maxStroke;
                    }
                    final menuLeftMax = math.max(4.0, w - menuOuterRadius * 2 - 4);
                    final menuTopMax = math.max(4.0, stackH - menuOuterRadius * 2 - 4);
                    return SizedBox(
                      height: stackH,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: _safeClampDouble(cx - menuOuterRadius, 4.0, menuLeftMax),
                            top: _safeClampDouble(cy - menuOuterRadius, 4.0, menuTopMax),
                            child: _MicSemicircleMenu(
                              size: menuOuterRadius * 2,
                              thickness: menuStroke,
                              items: [
                                _MicMenuItem(
                                  icon: state.isSyncing ? Icons.sync : Icons.sync_rounded,
                                  label: state.isSyncing ? tr('syncing', lang: lang) : tr('syncHub', lang: lang),
                                  onTap: _openSyncHub,
                                ),
                                _MicMenuItem(
                                  icon: Icons.camera_alt_outlined,
                                  label: tr('scan', lang: lang),
                                  onTap: _scanPaperAndOpenConfirm,
                                ),
                                _MicMenuItem(
                                  icon: Icons.keyboard_alt_outlined,
                                  label: tr('type', lang: lang),
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    await showStickyNoteAddTaskSheet(context);
                                  },
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: marginRight,
                            top: (stackH - micHit) / 2,
                            child: _TalkMicThumbButton(
                              isListening: _isListening,
                              purple: accent,
                              onTap: _toggleVoiceInput,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeProfileRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bp = context.bp;
    final lang = state.languageCode;
    final name = state.displayName;
    final label = state.welcomeBackLabel;
    final base64 = state.avatarBase64;
    final bytes = base64 == null || base64.isEmpty ? null : base64Decode(base64);

    final diameter = _talkScreenCm(context, 1.4);
    final radius = diameter / 2;

    String initials(String value) {
      final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (parts.isEmpty) return 'BP';
      if (parts.length == 1) {
        final s = parts.first;
        return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
      }
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: bp.primary.withValues(alpha: 0.18),
          backgroundImage: bytes == null ? null : MemoryImage(bytes),
          child: bytes == null
              ? Text(
                  initials(name.isNotEmpty ? name : tr('bubblesPageTitle', lang: lang)),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: bp.primary,
                      ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.left,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: bp.textSecondary.withValues(alpha: 0.85),
                ),
          ),
        ),
      ],
    );
  }
}

class _SpokenWordsBubbles extends StatelessWidget {
  const _SpokenWordsBubbles({
    required this.entries,
  });

  final List<_SpokenWordEntry> entries;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56, maxHeight: 98),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bp.listCardFill.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bp.listCardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _SpokenWordChip(entry: entries[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpokenWordEntry {
  const _SpokenWordEntry({
    required this.id,
    required this.word,
  });

  final int id;
  final String word;
}

class _SpokenWordChip extends StatelessWidget {
  const _SpokenWordChip({
    required this.entry,
  });

  final _SpokenWordEntry entry;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    return TweenAnimationBuilder<double>(
      key: ValueKey('spoken_word_${entry.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final flyDy = (1 - t) * 30;
        final textOpacity = 0.35 + t * 0.65;
        final appearScale = 0.92 + t * 0.08;
        return Transform.translate(
          offset: Offset(0, flyDy),
          child: Transform.scale(
            scale: appearScale,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Opacity(
                opacity: textOpacity,
                child: Text(
                  entry.word,
                  style: TextStyle(
                    color: bp.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: bp.talkAccent.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MicMenuItem {
  const _MicMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Клин по сектору полукруга (синх / type / scan) — попадание по форме дуги, не по квадрату.
class _SemicircleSegmentClipper extends CustomClipper<Path> {
  const _SemicircleSegmentClipper(this.index);

  final int index;

  static const double _start = math.pi / 2;
  static const double _sweep = math.pi / 3;

  @override
  Path getClip(Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final a0 = _start + _sweep * index;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + math.cos(a0) * r, c.dy + math.sin(a0) * r)
      ..arcTo(
        Rect.fromCircle(center: c, radius: r),
        a0,
        _sweep,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant _SemicircleSegmentClipper oldClipper) =>
      oldClipper.index != index;
}

class _MicSemicircleMenu extends StatelessWidget {
  const _MicSemicircleMenu({
    required this.size,
    required this.thickness,
    required this.items,
  }) : assert(items.length == 3);

  final double size;
  final double thickness;
  final List<_MicMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    final segmentFg =
        bp.brightness == Brightness.dark ? Colors.white : bp.textPrimary;
    const start = math.pi / 2;
    const sweep = math.pi / 3;
    final outerR = size / 2;
    final innerR = outerR - thickness;
    final midR = (outerR + innerR) / 2;
    final labelWidth = _safeClampDouble(size * 0.26, 72, 104);
    final iconSize = _safeClampDouble(size * 0.05, 14, 18);
    final labelFont = _safeClampDouble(size * 0.028, 8.5, 10.5);
    final labelGap = _safeClampDouble(size * 0.01, 1.5, 3.0);

    Offset centerForSegment(int i) {
      final a = start + sweep * i + sweep / 2;
      return Offset(
        outerR + math.cos(a) * midR,
        outerR + math.sin(a) * midR,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _SemicircleMenuPainter(
              thickness: thickness,
              selectedIndex: -1,
              selectedRingColor: bp.micSelectedRing,
              lightBackground: bp.brightness == Brightness.light,
            ),
          ),
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: size,
              child: ClipPath(
                clipper: _SemicircleSegmentClipper(i),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: items[i].onTap,
                    child: Stack(
                      children: [
                        Positioned(
                          left: centerForSegment(i).dx - labelWidth / 2,
                          top: centerForSegment(i).dy - 28,
                          width: labelWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(items[i].icon, size: iconSize, color: segmentFg),
                              SizedBox(height: labelGap),
                              Text(
                                items[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: segmentFg,
                                  fontSize: labelFont,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SemicircleMenuPainter extends CustomPainter {
  const _SemicircleMenuPainter({
    required this.thickness,
    required this.selectedIndex,
    required this.selectedRingColor,
    required this.lightBackground,
  });

  final double thickness;
  final int selectedIndex;
  final Color selectedRingColor;
  final bool lightBackground;

  @override
  void paint(Canvas canvas, Size size) {
    const start = math.pi / 2;
    const sweep = math.pi / 3;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - thickness / 2;

    final gradColors = lightBackground
        ? const [Color(0x4D000000), Color(0x26000000)]
        : const [Color(0x2DFFFFFF), Color(0x12FFFFFF)];

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = thickness
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradColors,
      ).createShader(Rect.fromCircle(center: c, radius: r));

    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, math.pi, false, base);

    if (selectedIndex >= 0) {
      final sel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = thickness
        ..color = selectedRingColor;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start + sweep * selectedIndex,
        sweep,
        false,
        sel,
      );
    }

    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = lightBackground
          ? const Color(0x33000000)
          : Colors.white.withValues(alpha: 0.22);
    for (var i = 1; i < 3; i++) {
      final a = start + sweep * i;
      final p1 = Offset(c.dx + math.cos(a) * (r - thickness / 2), c.dy + math.sin(a) * (r - thickness / 2));
      final p2 = Offset(c.dx + math.cos(a) * (r + thickness / 2), c.dy + math.sin(a) * (r + thickness / 2));
      canvas.drawLine(p1, p2, divider);
    }
  }

  @override
  bool shouldRepaint(covariant _SemicircleMenuPainter oldDelegate) {
    return oldDelegate.thickness != thickness ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.selectedRingColor != selectedRingColor ||
        oldDelegate.lightBackground != lightBackground;
  }
}

/// Крупный микрофон: +18% к базовым 104/112 dp; зона нажатия — круг.
class _TalkMicThumbButton extends StatelessWidget {
  const _TalkMicThumbButton({
    required this.isListening,
    required this.purple,
    required this.onTap,
  });

  final bool isListening;
  final Color purple;
  final VoidCallback onTap;

  /// Базовые 104×112, +18%.
  static const double visualSize = 122.72;
  static const double hitSize = 132.16;

  @override
  Widget build(BuildContext context) {
    const recordingAccent = Color(0xFFFF4F88);
    final accent = isListening ? recordingAccent : purple;
    final fillColor = isListening
        ? const Color(0xFF3B0E1E).withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.45);
    final micIcon = isListening ? Icons.stop_rounded : Icons.mic_none_rounded;
    return Semantics(
      button: true,
      label: isListening ? 'Stop recording' : 'Microphone',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: hitSize,
            height: hitSize,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fillColor,
                  border: Border.all(color: accent, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: isListening ? 0.78 : 0.5),
                      blurRadius: isListening ? 34 : 26,
                      spreadRadius: isListening ? 2.2 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  micIcon,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Единый стиль с основными кнопками приложения: полная ширина, скругление, акцент.
class _PrimaryToolRow extends StatelessWidget {
  const _PrimaryToolRow({
    this.icon,
    this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    final titleColor = bp.textPrimary;
    final subtitleColor = bp.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Ink(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: accent.withValues(alpha: bp.brightness == Brightness.dark ? 0.2 : 0.14),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: bp.navShadow.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.22),
                ),
                child: Center(
                  child: iconWidget ??
                      Icon(
                        icon,
                        size: 22,
                        color: accent,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onChanged,
    required this.onToolsTap,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onToolsTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    final bp = context.bp;
    final items = [
      _NavItem(icon: Icons.chat_bubble_outline_rounded, label: tr('navTalk', lang: lang)),
      _NavItem(icon: Icons.grid_view_rounded, label: tr('navBubbles', lang: lang)),
      _NavItem(icon: Icons.list_alt_rounded, label: tr('navList', lang: lang)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: bp.navBarBg,
        boxShadow: [
          BoxShadow(
            color: bp.navShadow,
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < items.length; i++)
                  _BottomNavItem(
                    item: items[i],
                    isActive: i == currentIndex,
                    onTap: () => onChanged(i),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _FooterToolsButton(
            label: tr('footerToolsLabel', lang: lang),
            onTap: onToolsTap,
          ),
        ],
      ),
    );
  }
}

class _FooterToolsButton extends StatelessWidget {
  const _FooterToolsButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    final iconColor = bp.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bp.footerToolsFill,
            border: Border.all(color: bp.footerToolsBorder),
            boxShadow: [
              BoxShadow(
                color: bp.navShadow.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Tooltip(
            message: label,
            child: Icon(
              Icons.sticky_note_2_rounded,
              size: 20,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    final color = isActive ? Theme.of(context).colorScheme.primary : bp.navInactive;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? bp.navActiveHighlight : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    final g = context.bp.backgroundGradient;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: g,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: bp.glassFill,
              shape: BoxShape.circle,
              border: Border.all(color: bp.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: bp.navShadow,
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: 21, color: bp.glassIcon),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bp.brandGradientStart, bp.brandGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: bp.talkAccent.withValues(alpha: 0.45),
            blurRadius: 16,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'B',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
