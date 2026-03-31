import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_state.dart';
import 'convex_env.dart';
import 'app_theme.dart';
import 'translations.dart';
import 'services/paper_scan.dart';
import 'screens/login_screen.dart';
import 'tabs/tasks_list_tab.dart';
import 'widgets/bubble_widget.dart';
import 'widgets/confirm_task_sheet.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/pomodoro_sheet.dart';
import 'widgets/sync_hub_sheet.dart';
import 'widgets/task_row_quick_actions.dart';

/// Сантиметры → логические px по короткой стороне экрана (~6.5 см типичная ширина контента в руке).
double _talkScreenCm(BuildContext context, double cm) {
  final s = MediaQuery.sizeOf(context).shortestSide;
  return s * (cm / 6.5);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bubble Planner',
      locale: Locale(state.languageCode),
      theme: AppTheme.dark(state.fontChoice),
      home: state.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Offset _parallax = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = <Widget>[
      _TalkPage(onSearchTap: () => setState(() => _currentIndex = 2)),
      _BubblesPage(
        parallax: _parallax,
        onParallax: (value) => setState(() => _parallax = value),
        onSearchTap: () => setState(() => _currentIndex = 2),
      ),
      const TasksListTab(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const _GradientBackground(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: pages[_currentIndex],
            ),
          ),
          if (_currentIndex != 2)
            Positioned(
              top: 10,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${tr('done', lang: state.languageCode)}: ${state.doneCount}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF22C55E),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '${tr('pending', lang: state.languageCode)}: ${state.activeCount}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFFFBBF24),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onChanged: (index) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
        onPomodoroTap: () => PomodoroHomeButton.open(context),
      ),
    );
  }
}

class _BubblesPage extends StatelessWidget {
  const _BubblesPage({
    required this.parallax,
    required this.onParallax,
    required this.onSearchTap,
  });

  final Offset parallax;
  final ValueChanged<Offset> onParallax;
  final VoidCallback onSearchTap;

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
                icon: Icons.settings_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SettingsSheet(),
                  );
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
                                child: CategoryTasksScreen(category: item),
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

class CategoryTasksScreen extends StatelessWidget {
  const CategoryTasksScreen({super.key, required this.category});

  final BubbleCategory category;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allTasks = state.tasksByCategory(category.id);
    final now = DateTime.now();
    final todayTasks = allTasks.where((t) {
      final d = t.dueAt;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
    final followingTasks = allTasks.where((t) {
      final d = t.dueAt;
      return !(d.year == now.year && d.month == now.month && d.day == now.day);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF141516), Color(0xFF101113)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${tr('done', lang: state.languageCode).toUpperCase()}: ${state.doneCount}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF00E675),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${tr('pending', lang: state.languageCode).toUpperCase()}: ${state.activeCount}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFFFB300),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F4),
                      borderRadius: BorderRadius.circular(34),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                          child: Row(
                            children: [
                              Text(
                                '${category.title} (${allTasks.length})',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: const Color(0xFF1D1A1A),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const Spacer(),
                              _IconAction(
                                icon: Icons.add,
                                onTap: () => _openAddTaskDialog(context),
                              ),
                              _IconAction(
                                icon: Icons.search,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(tr('searchOpened', lang: state.languageCode)),
                                    ),
                                  );
                                },
                              ),
                              _IconAction(
                                icon: Icons.share_outlined,
                                onTap: () {
                                  final text = allTasks.map((e) => e.title).join('\n');
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(tr('tasksCopied', lang: state.languageCode)),
                                    ),
                                  );
                                },
                              ),
                              _IconAction(
                                icon: Icons.delete_outline_rounded,
                                onTap: () {
                                  for (final t in allTasks) {
                                    context.read<AppState>().deleteTask(t.id);
                                  }
                                },
                              ),
                              _IconAction(
                                icon: Icons.close_rounded,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFDADADA)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
                          child: Row(
                            children: [
                              _HeaderCell(tr('headerDue', lang: state.languageCode), width: 68),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _HeaderCell(tr('headerTaskDetails', lang: state.languageCode)),
                              ),
                              _HeaderCell(tr('headerStat', lang: state.languageCode), width: 40),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFDADADA)),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                            children: [
                              if (todayTasks.isNotEmpty) ...[
                                _SectionLabel(tr('todaySection', lang: state.languageCode)),
                                const SizedBox(height: 6),
                                for (final task in todayTasks)
                                  _OpenBubbleTaskTile(
                                    task: task,
                                    onToggle: () =>
                                        context.read<AppState>().toggleTaskDone(task.id),
                                    timeText: state.formatDueTime(task.dueAt),
                                    dayText: state.formatDueDay(task.dueAt),
                                  ),
                              ],
                              if (followingTasks.isNotEmpty) ...[
                                _SectionLabel(tr('followingDaysSection', lang: state.languageCode)),
                                const SizedBox(height: 6),
                                for (final task in followingTasks)
                                  _OpenBubbleTaskTile(
                                    task: task,
                                    onToggle: () =>
                                        context.read<AppState>().toggleTaskDone(task.id),
                                    timeText: state.formatDueTime(task.dueAt),
                                    dayText: state.formatDueDay(task.dueAt),
                                  ),
                              ],
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2E8DE),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7CFAE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wb_sunny_outlined, color: Color(0xFFF0A92D)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr('enableDailyRoutinesBanner', lang: state.languageCode),
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: const Color(0xFFE2A221),
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              Switch.adaptive(
                                value: state.dailyRoutinesEnabled,
                                onChanged: (v) =>
                                    context.read<AppState>().toggleDailyRoutines(v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAddTaskDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final lang = dialogContext.read<AppState>().languageCode;
        return AlertDialog(
          title: Text(tr('addTask', lang: lang)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: tr('taskTextHint', lang: lang)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('cancel', lang: lang)),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  context.read<AppState>().addTaskFromText(text);
                }
                Navigator.pop(dialogContext);
              },
              child: Text(tr('addButton', lang: lang)),
            ),
          ],
        );
      },
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF3A3A3A)),
      splashRadius: 20,
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.width});

  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF8A8A8A),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
    );
    if (width == null) return child;
    return SizedBox(width: width, child: child);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFFF3B51D),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
      ),
    );
  }
}

class _OpenBubbleTaskTile extends StatelessWidget {
  const _OpenBubbleTaskTile({
    required this.task,
    required this.onToggle,
    required this.timeText,
    required this.dayText,
  });

  final BubbleTaskItem task;
  final VoidCallback onToggle;
  final String timeText;
  final String dayText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFE04747),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFB5B5B5),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    _ReminderChip('5M'),
                    SizedBox(width: 6),
                    _ReminderChip('30M'),
                    SizedBox(width: 6),
                    _ReminderChip('1H'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF202020),
                        fontWeight: FontWeight.w700,
                        decoration:
                            task.isDone ? TextDecoration.lineThrough : null,
                      ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => Padding(
                          padding: EdgeInsets.only(
                            left: 12,
                            right: 12,
                            bottom: MediaQuery.paddingOf(ctx).bottom + 12,
                          ),
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: TaskQuickActionsRow(
                                task: task,
                                hostContext: context,
                                onBeforeAction: () => Navigator.pop(ctx),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.more_vert, color: Color(0xFF9A9A9A)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 34),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFA9A9A9), width: 2),
                borderRadius: BorderRadius.circular(6),
                color: task.isDone ? const Color(0xFF19C66D) : Colors.transparent,
              ),
              child: task.isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
      ),
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
  static const _purple = Color(0xFF8B5CF6);

  final SpeechToText _speech = SpeechToText();
  final TextEditingController _typeController = TextEditingController();
  bool _isListening = false;
  String _capturedText = '';
  bool _typeMode = false;

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _openConfirmSheet({String initial = ''}) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConfirmTaskSheet(initialTitle: initial),
    );
  }

  /// Сканирование бумажной записи (камера/галерея → OCR на Android/iOS).
  Future<void> _scanPaperAndOpenConfirm() async {
    HapticFeedback.lightImpact();
    final text = await scanTextFromPaper(context);
    if (!mounted) return;
    if (text == null) return;
    await _openConfirmSheet(initial: text);
  }

  Future<void> _toggleVoiceInput() async {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_capturedText.trim().isNotEmpty && mounted) {
        await _openConfirmSheet(initial: _capturedText);
      }
      return;
    }
    final available = await _speech.initialize();
    if (!available || !mounted) return;
    setState(() {
      _capturedText = '';
      _isListening = true;
    });
    await _speech.listen(
      onResult: (result) {
        setState(() => _capturedText = result.recognizedWords);
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.languageCode;
    return Column(
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
                icon: Icons.settings_rounded,
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SettingsSheet(),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                ),
                          ),
                          TextSpan(
                            text: 'Planner',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: _purple,
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
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isListening ? tr('listeningHint', lang: lang) : tr('tapToTalk', lang: lang),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 24),
                Text(
                  tr('welcomeBackDemo', lang: lang),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
        if (_typeMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.keyboard_alt_outlined, color: Colors.white.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _typeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: tr('typeYourTaskHint', lang: lang),
                        hintStyle: const TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) {
                          context.read<AppState>().addTaskFromText(v);
                          _typeController.clear();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () => _typeController.clear(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  ),
                  Material(
                    color: _purple,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        final v = _typeController.text.trim();
                        if (v.isNotEmpty) {
                          context.read<AppState>().addTaskFromText(v);
                          _typeController.clear();
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Микрофон: ~3 см от правого края, +18%; трапеции — полукругом вокруг (шаг ~2.5 см по дуге).
        Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 6 + MediaQuery.paddingOf(context).bottom),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const trapW = _TalkTrapezoidChip.w;
              const trapH = _TalkTrapezoidChip.h;
              final micHit = _TalkMicThumbButton.hitSize;
              final marginRight = _talkScreenCm(context, 3.0);
              final arcLen = _talkScreenCm(context, 2.5);
              final radius = arcLen / (math.pi / 3);
              const stackH = 340.0;
              final w = constraints.maxWidth;
              final cx = w - marginRight - micHit / 2;
              final cy = stackH / 2;
              const angles = [2 * math.pi / 3, math.pi, 4 * math.pi / 3];
              return SizedBox(
                height: stackH,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Positioned(
                        left: (cx + math.cos(angles[i]) * radius - trapW / 2).clamp(4.0, w - trapW - 4),
                        top: (cy - math.sin(angles[i]) * radius - trapH / 2).clamp(4.0, stackH - trapH - 4),
                        child: _TalkTrapezoidChip(
                          variant: i == 0
                              ? _TalkTrapezoidVariant.syncTopRight
                              : i == 1
                                  ? _TalkTrapezoidVariant.scanLeft
                                  : _TalkTrapezoidVariant.typeBottomRight,
                          icon: i == 0
                              ? (state.isSyncing ? Icons.sync : Icons.sync_rounded)
                              : i == 1
                                  ? Icons.camera_alt_outlined
                                  : Icons.keyboard_alt_outlined,
                          label: i == 0
                              ? (state.isSyncing ? tr('syncing', lang: lang) : tr('syncHub', lang: lang))
                              : i == 1
                                  ? tr('scan', lang: lang)
                                  : tr('type', lang: lang),
                          selected: i == 2 && _typeMode,
                          onTap: i == 0
                              ? _openSyncHub
                              : i == 1
                                  ? _scanPaperAndOpenConfirm
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _typeMode = !_typeMode);
                                    },
                        ),
                      ),
                    Positioned(
                      right: marginRight,
                      top: (stackH - micHit) / 2,
                      child: _TalkMicThumbButton(
                        isListening: _isListening,
                        purple: _purple,
                        onTap: _toggleVoiceInput,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _TalkTrapezoidVariant { syncTopRight, scanLeft, typeBottomRight }

class _TalkTrapezoidClipper extends CustomClipper<Path> {
  _TalkTrapezoidClipper(this.variant);

  final _TalkTrapezoidVariant variant;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final t = h * 0.22;
    switch (variant) {
      case _TalkTrapezoidVariant.syncTopRight:
        return Path()
          ..moveTo(t, 0)
          ..lineTo(w, 0)
          ..lineTo(w - t * 0.4, h)
          ..lineTo(0, h - t * 0.5)
          ..close();
      case _TalkTrapezoidVariant.scanLeft:
        return Path()
          ..moveTo(0, t * 0.4)
          ..lineTo(w - t, 0)
          ..lineTo(w, h)
          ..lineTo(t * 0.3, h)
          ..close();
      case _TalkTrapezoidVariant.typeBottomRight:
        return Path()
          ..moveTo(t, 0)
          ..lineTo(w, t * 0.35)
          ..lineTo(w - t * 0.2, h)
          ..lineTo(0, h - t * 0.35)
          ..close();
    }
  }

  @override
  bool shouldReclip(covariant _TalkTrapezoidClipper oldClipper) => oldClipper.variant != variant;
}

/// Трапециевидная кнопка как на эскизе (ориентация к центральному кругу).
class _TalkTrapezoidChip extends StatelessWidget {
  const _TalkTrapezoidChip({
    required this.variant,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _TalkTrapezoidVariant variant;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _purple = Color(0xFF8B5CF6);

  static const double w = 118;
  static const double h = 52;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipPath(
        clipper: _TalkTrapezoidClipper(variant),
        child: Material(
          color: selected ? _purple.withValues(alpha: 0.38) : Colors.white.withValues(alpha: 0.08),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: w,
              height: h,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    return Semantics(
      button: true,
      label: 'Microphone',
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
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: purple, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: purple.withValues(alpha: 0.5),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
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

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onChanged,
    required this.onPomodoroTap,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onPomodoroTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    final items = [
      _NavItem(icon: Icons.chat_bubble_outline_rounded, label: tr('navTalk', lang: lang)),
      _NavItem(icon: Icons.grid_view_rounded, label: tr('navBubbles', lang: lang)),
      _NavItem(icon: Icons.list_alt_rounded, label: tr('navList', lang: lang)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1018).withOpacity(0.92),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -8),
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
          _FooterPomodoroButton(
            label: tr('pomodoroFooterLabel', lang: lang),
            onTap: onPomodoroTap,
          ),
        ],
      ),
    );
  }
}

class _FooterPomodoroButton extends StatelessWidget {
  const _FooterPomodoroButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFFD83A35).withValues(alpha: 0.22),
            border: Border.all(color: const Color(0xFFE35A52)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PomodoroTomatoIcon(size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
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
    final color =
        isActive ? Theme.of(context).colorScheme.primary : Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.08) : Colors.transparent,
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0612),
            Color(0xFF12081F),
            Color(0xFF1A0F08),
          ],
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
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.32),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: 21, color: Colors.white.withOpacity(0.92)),
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
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFB794F6),
            Color(0xFF6B21A8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF8B5CF6).withValues(alpha: 0.5),
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
