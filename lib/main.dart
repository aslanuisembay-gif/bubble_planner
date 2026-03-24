import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'widgets/bubble_widget.dart';
import 'widgets/settings_sheet.dart';

void main() => runApp(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const BubblePlannerApp(),
      ),
    );

class BubblePlannerApp extends StatelessWidget {
  const BubblePlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bubble Planner',
      theme: AppTheme.dark(state.fontChoice),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;
  Offset _parallax = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = <Widget>[
      const _TalkPage(),
      _BubblesPage(
        parallax: _parallax,
        onParallax: (value) => setState(() => _parallax = value),
      ),
      const _SimpleTab(title: 'List'),
      const _SimpleTab(title: 'Share'),
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
          if (_currentIndex == 1)
            Positioned(
              top: 68,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Done: ${state.doneCount}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.done,
                        ),
                  ),
                  Text(
                    'Active: ${state.activeCount}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.active,
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
      ),
    );
  }
}

class _BubblesPage extends StatelessWidget {
  const _BubblesPage({required this.parallax, required this.onParallax});

  final Offset parallax;
  final ValueChanged<Offset> onParallax;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<AppState>().categories;
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: Row(
            children: [
              Text(
                'Bubbles',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Spacer(),
              _GlassIconButton(icon: Icons.search_rounded, onTap: () {}),
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
                        'DONE: ${state.doneCount}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF00E675),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ACTIVE: ${state.activeCount}',
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
                                    const SnackBar(content: Text('Search opened')),
                                  );
                                },
                              ),
                              _IconAction(
                                icon: Icons.share_outlined,
                                onTap: () {
                                  final text = allTasks.map((e) => e.title).join('\n');
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tasks copied')),
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
                              _HeaderCell('DUE', width: 68),
                              const SizedBox(width: 8),
                              const Expanded(child: _HeaderCell('TASK DETAILS')),
                              _HeaderCell('STAT', width: 40),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFDADADA)),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                            children: [
                              if (todayTasks.isNotEmpty) ...[
                                const _SectionLabel('TODAY'),
                                const SizedBox(height: 6),
                                for (final task in todayTasks)
                                  _OpenBubbleTaskTile(
                                    task: task,
                                    onToggle: () =>
                                        context.read<AppState>().toggleTaskDone(task.id),
                                    onDelete: () =>
                                        context.read<AppState>().deleteTask(task.id),
                                    timeText: state.formatDueTime(task.dueAt),
                                    dayText: state.formatDueDay(task.dueAt),
                                  ),
                              ],
                              if (followingTasks.isNotEmpty) ...[
                                const _SectionLabel('FOLLOWING DAYS'),
                                const SizedBox(height: 6),
                                for (final task in followingTasks)
                                  _OpenBubbleTaskTile(
                                    task: task,
                                    onToggle: () =>
                                        context.read<AppState>().toggleTaskDone(task.id),
                                    onDelete: () =>
                                        context.read<AppState>().deleteTask(task.id),
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
                                  'ENABLE DAILY ROUTINES',
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
        return AlertDialog(
          title: const Text('Add task'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Task text'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  context.read<AppState>().addTaskFromText(text);
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
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
    required this.onDelete,
    required this.timeText,
    required this.dayText,
  });

  final BubbleTaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
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
                    onPressed: onDelete,
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

class _SimpleTab extends StatelessWidget {
  const _SimpleTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title coming soon',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white70,
            ),
      ),
    );
  }
}

class _TalkPage extends StatefulWidget {
  const _TalkPage();

  @override
  State<_TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<_TalkPage> {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _capturedText = '';

  Future<void> _toggleVoiceInput() async {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_capturedText.trim().isNotEmpty && mounted) {
        context.read<AppState>().addTaskFromText(_capturedText);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added by voice: $_capturedText')),
        );
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

  Future<void> _openTaskInputDialog({required String title}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter task text',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (!mounted || value == null || value.isEmpty) return;
    context.read<AppState>().addTaskFromText(value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added: $value')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      color: const Color(0xFFF2EEE7),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Row(
              children: [
                const Spacer(),
                _LightCircleIcon(icon: Icons.search, onTap: () {}),
                const SizedBox(width: 8),
                _LightCircleIcon(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Row(
              children: [
                const _BrandMark(),
                const SizedBox(width: 8),
                Text(
                  'ubblePlanner',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF1E1E1E),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Done: ${state.doneCount}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.done,
                          ),
                    ),
                    Text(
                      'Active: ${state.activeCount}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.active,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Ready for tasks',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: const Color(0xFF201B1B),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _isListening ? 'Listening... tap again to save' : 'Tap the button to talk',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF2F2727),
                ),
          ),
          const SizedBox(height: 34),
          GestureDetector(
            onTap: _toggleVoiceInput,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF2ECDD),
                    const Color(0xFF6D6862),
                  ],
                  center: const Alignment(0.0, -0.15),
                ),
                border: Border.all(
                  color: _isListening
                      ? const Color(0xFF6CA8FF)
                      : const Color(0xFF4A89FF),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.32),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                size: 64,
                color: const Color(0xFF2E2320),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _TalkActionButton(
                    icon: state.isSyncing ? Icons.sync : Icons.sync_rounded,
                    label: state.isSyncing ? 'SYNCING' : 'SYNC HUB',
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await context.read<AppState>().syncHub();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Synced successfully')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TalkActionButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'SCAN',
                    onTap: () => _openTaskInputDialog(title: 'Scan task text'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TalkActionButton(
                    icon: Icons.keyboard_alt_outlined,
                    label: 'TYPE',
                    onTap: () => _openTaskInputDialog(title: 'Type a task'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      const _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'TALK'),
      const _NavItem(icon: Icons.grid_view_rounded, label: 'BUBBLES'),
      const _NavItem(icon: Icons.list_alt_rounded, label: 'LIST'),
      const _NavItem(icon: Icons.share_outlined, label: 'SHARE'),
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
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF12353B).withOpacity(0.75),
            const Color(0xFF141A2A),
            const Color(0xFF1E1417),
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

class _LightCircleIcon extends StatelessWidget {
  const _LightCircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(icon, color: Colors.black45),
      ),
    );
  }
}

class _TalkActionButton extends StatelessWidget {
  const _TalkActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.45),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black45),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
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
            Color(0xFF98CCFF),
            Color(0xFF3B79E8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B79E8).withOpacity(0.5),
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
