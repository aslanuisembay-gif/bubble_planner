import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const BubblePlannerApp());
}

/// Основное приложение Bubble Planner.
class BubblePlannerApp extends StatelessWidget {
  const BubblePlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        background: Color(0xFF050509),
        surface: Color(0xFF181820),
        primary: Color(0xFF4DA6FF),
        secondary: Color(0xFFFFB800),
        tertiary: Color(0xFF8A2BE2),
      ),
      scaffoldBackgroundColor: const Color(0xFF050509),
      fontFamily: 'Outfit',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          letterSpacing: 0.1,
        ),
      ),
    );

    return MaterialApp(
      title: 'Bubble Planner',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      home: const BubblePlannerRoot(),
    );
  }
}

/// Статусы задач как в React-версии.
enum TaskStatus { active, done }

/// Модель задачи.
class Task {
  Task({
    required this.id,
    required this.text,
    required this.category,
    required this.status,
    this.dueAt,
  });

  final String id;
  final String text;
  final String category; // 'Покупки', 'Работа', ...
  final TaskStatus status;
  final DateTime? dueAt;

  Task copyWith({
    String? id,
    String? text,
    String? category,
    TaskStatus? status,
    DateTime? dueAt,
  }) {
    return Task(
      id: id ?? this.id,
      text: text ?? this.text,
      category: category ?? this.category,
      status: status ?? this.status,
      dueAt: dueAt ?? this.dueAt,
    );
  }
}

/// Расчёт статистики пузыря по задачам категории (порт из utils.js).
class BubbleStats {
  const BubbleStats({
    required this.size,
    required this.urgencyScore,
    required this.openTaskCount,
  });

  final double size;
  final int urgencyScore;
  final int openTaskCount;
}

BubbleStats calculateBubbleStats(List<Task> tasks) {
  final activeTasks =
      tasks.where((t) => t.status != TaskStatus.done).toList(growable: false);
  final count = activeTasks.length;

  var urgencyScore = 0;
  final now = DateTime.now();

  for (final task in activeTasks) {
    final dueAt = task.dueAt;
    if (dueAt != null) {
      final diff = dueAt.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
      final hours = diff / 3600000;
      final days = hours / 24;

      if (hours <= 24) {
        urgencyScore += 5;
      } else if (days <= 3) {
        urgencyScore += 3;
      } else if (days <= 7) {
        urgencyScore += 2;
      } else {
        urgencyScore += 1;
      }
    } else {
      urgencyScore += 1;
    }
  }

  const baseSize = 78.0;
  const k1 = 5.0;
  const k2 = 7.0;
  const minSize = 85.0;
  const maxSize = 160.0;

  final size = (baseSize + urgencyScore * k1 + count * k2)
      .clamp(minSize, maxSize)
      .toDouble();

  return BubbleStats(
    size: size,
    urgencyScore: urgencyScore,
    openTaskCount: count,
  );
}

/// Простейший репозиторий задач — отдельный слой под будущий Convex.
class TaskRepository {
  TaskRepository() : _random = Random();

  final Random _random;

  // Базовые семена задач из React-версии.
  Future<List<Task>> loadInitialTasks() async {
    final now = DateTime.now();
    final tasks = <Task>[
      Task(
        id: _genId(),
        text: 'Купить молоко и хлеб',
        category: 'Покупки',
        status: TaskStatus.active,
        dueAt: now.add(const Duration(hours: 5)),
      ),
      Task(
        id: _genId(),
        text: 'Подготовить презентацию',
        category: 'Работа',
        status: TaskStatus.active,
        dueAt: now.add(const Duration(days: 1)),
      ),
      Task(
        id: _genId(),
        text: 'Записаться к врачу',
        category: 'Здоровье',
        status: TaskStatus.active,
        dueAt: now.add(const Duration(days: 3)),
      ),
      Task(
        id: _genId(),
        text: 'Играть с детьми',
        category: 'Дети',
        status: TaskStatus.active,
        dueAt: now.add(const Duration(days: 2)),
      ),
      Task(
        id: _genId(),
        text: 'Оплатить счета',
        category: 'Финансы',
        status: TaskStatus.active,
        dueAt: now.add(const Duration(days: 4)),
      ),
      Task(
        id: _genId(),
        text: 'Сделать генеральную уборку',
        category: 'Дом',
        status: TaskStatus.active,
      ),
    ];
    return tasks;
  }

  String _genId() =>
      DateTime.now().microsecondsSinceEpoch.toString() +
      _random.nextInt(999999).toString().padLeft(6, '0');

  Future<void> saveTasks(List<Task> tasks) async {
    // Точка расширения под Convex: здесь можно вызывать клиент Convex
    // и синхронизировать список задач.
    await Future<void>.value();
  }
}

/// Корневой экран с нижней навигацией (Talk / Bubbles / List / Share).
class BubblePlannerRoot extends StatefulWidget {
  const BubblePlannerRoot({super.key});

  @override
  State<BubblePlannerRoot> createState() => _BubblePlannerRootState();
}

class _BubblePlannerRootState extends State<BubblePlannerRoot> {
  final TaskRepository _repository = TaskRepository();

  int _currentIndex = 1; // По умолчанию вкладка Bubbles.
  List<Task> _tasks = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await _repository.loadInitialTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  void _updateTasks(List<Task> tasks) {
    setState(() {
      _tasks = tasks;
    });
    _repository.saveTasks(tasks);
  }

  void _toggleTaskStatus(Task task) {
    final updated = task.copyWith(
      status:
          task.status == TaskStatus.done ? TaskStatus.active : TaskStatus.done,
    );
    final newTasks = _tasks.map((t) => t.id == task.id ? updated : t).toList();
    _updateTasks(newTasks);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _tasks.where((t) => t.status == TaskStatus.active).length;
    final doneCount = _tasks.where((t) => t.status == TaskStatus.done).length;

    final pages = [
      _TalkPlaceholder(doneCount: doneCount, activeCount: activeCount),
      BubblesScreen(
        tasks: _tasks,
        isLoading: _isLoading,
        onToggleTaskStatus: _toggleTaskStatus,
      ),
      _ListPlaceholder(tasks: _tasks),
      _SharePlaceholder(taskCount: _tasks.length),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const _GradientBackground(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: pages[_currentIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

/// Экран пузырей — основная часть приложения.
class BubblesScreen extends StatelessWidget {
  const BubblesScreen({
    super.key,
    required this.tasks,
    required this.isLoading,
    required this.onToggleTaskStatus,
  });

  final List<Task> tasks;
  final bool isLoading;
  final void Function(Task task) onToggleTaskStatus;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupTasksByCategory(tasks);

    final doneCount =
        tasks.where((t) => t.status == TaskStatus.done).length.toString();
    final activeCount =
        tasks.where((t) => t.status == TaskStatus.active).length.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const _AppIcon(),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'bubblePlanner',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'Bubbles',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Dones $doneCount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5BFF7F),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'Actives $activeCount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFFD54F),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Search tasks or categories...',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CircleIconButton(
                icon: Icons.settings_outlined,
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _BubblesCanvasView(
                  grouped: grouped,
                  onToggleTaskStatus: onToggleTaskStatus,
                ),
        ),
      ],
    );
  }
}

class _BubblesCanvasView extends StatelessWidget {
  const _BubblesCanvasView({
    required this.grouped,
    required this.onToggleTaskStatus,
  });

  final Map<String, List<Task>> grouped;
  final void Function(Task task) onToggleTaskStatus;

  @override
  Widget build(BuildContext context) {
    if (grouped.isEmpty) {
      return Center(
        child: Text(
          'Your bubbles will float here',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.6),
              ),
        ),
      );
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final entry in entries)
                _CategoryBubble(
                  category: entry.key,
                  tasks: entry.value,
                  maxWidth: constraints.maxWidth,
                  onToggleTaskStatus: onToggleTaskStatus,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({
    required this.category,
    required this.tasks,
    required this.maxWidth,
    required this.onToggleTaskStatus,
  });

  final String category;
  final List<Task> tasks;
  final double maxWidth;
  final void Function(Task task) onToggleTaskStatus;

  @override
  Widget build(BuildContext context) {
    final stats = calculateBubbleStats(tasks);
    final color = _getCategoryColor(category);

    final double bubbleSize =
        stats.size.clamp(110.0, maxWidth * 0.7) as double;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return _BubbleDetailsSheet(
              category: category,
              color: color,
              tasks: tasks,
              onToggleTaskStatus: onToggleTaskStatus,
            );
          },
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: bubbleSize,
        height: bubbleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.9),
              color.withOpacity(0.6),
              Colors.black.withOpacity(0.85),
            ],
            center: const Alignment(-0.4, -0.6),
            radius: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.7),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getCategoryTitle(category),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.openTaskCount} tasks',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleDetailsSheet extends StatelessWidget {
  const _BubbleDetailsSheet({
    required this.category,
    required this.color,
    required this.tasks,
    required this.onToggleTaskStatus,
  });

  final String category;
  final Color color;
  final List<Task> tasks;
  final void Function(Task task) onToggleTaskStatus;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sorted = [...tasks]
      ..sort((a, b) {
        final aDue = a.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDue = b.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDue.compareTo(bDue);
      });

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: media.viewInsets.bottom + 16,
        top: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: const Color(0xFF12121A),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color,
                            color.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCategoryTitle(category),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${tasks.length} tasks',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.6),
                              ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x22FFFFFF)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final task = sorted[index];
                    final isDone = task.status == TaskStatus.done;
                    return InkWell(
                      onTap: () => onToggleTaskStatus(task),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDone
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: isDone
                                  ? const Color(0xFF5BFF7F)
                                  : Colors.white.withOpacity(0.6),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.text,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          decoration: isDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isDone
                                              ? Colors.white.withOpacity(0.5)
                                              : Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDue(task.dueAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              Colors.white.withOpacity(0.5),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDue(DateTime? due) {
    if (due == null) return 'No deadline';
    final now = DateTime.now();
    final diff = due.difference(now);
    final prefix = diff.isNegative ? 'Overdue · ' : 'Due · ';
    final hours = due.hour.toString().padLeft(2, '0');
    final minutes = due.minute.toString().padLeft(2, '0');
    final date =
        '${due.day.toString().padLeft(2, '0')}.${due.month.toString().padLeft(2, '0')}';
    return '$prefix$date $hours:$minutes';
  }
}

/// Вспомогательные плейсхолдеры для других вкладок (Talk/List/Share).
class _TalkPlaceholder extends StatelessWidget {
  const _TalkPlaceholder({
    required this.doneCount,
    required this.activeCount,
  });

  final int doneCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const _AppIcon(size: 60),
        const SizedBox(height: 16),
        Text(
          'Ready for tasks',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap the button to talk (stub)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.6),
              ),
        ),
        const SizedBox(height: 28),
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [
                Color(0xFF2C3855),
                Color(0xFF101420),
              ],
              center: Alignment.topLeft,
              radius: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4DA6FF).withOpacity(0.6),
                blurRadius: 35,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.mic_rounded,
            size: 54,
            color: Colors.white.withOpacity(0.95),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Text(
            'Dones $doneCount · Actives $activeCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.6),
                ),
          ),
        ),
      ],
    );
  }
}

class _ListPlaceholder extends StatelessWidget {
  const _ListPlaceholder({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'List (coming soon)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Here you will see all tasks as a flat list.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return ListTile(
                  title: Text(task.text),
                  subtitle: Text(task.category),
                );
              },
              separatorBuilder: (_, __) => const Divider(
                color: Color(0x22FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharePlaceholder extends StatelessWidget {
  const _SharePlaceholder({required this.taskCount});

  final int taskCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.ios_share_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Share (stub)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Later you\'ll be able to export $taskCount tasks.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Нижний таб-бар, стилизованный под скрины.
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
      _NavItem(icon: Icons.chat_bubble_outline, label: 'TALK'),
      _NavItem(icon: Icons.grid_view_rounded, label: 'BUBBLES'),
      _NavItem(icon: Icons.list_alt_rounded, label: 'LIST'),
      _NavItem(icon: Icons.share_outlined, label: 'SHARE'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF050509).withOpacity(0.95),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -6),
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
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Colors.white.withOpacity(0.5);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.06) : Colors.transparent,
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
                    letterSpacing: 0.8,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Градиентный фон, близкий к скринам Bubbles.
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
            Color(0xFF050509),
            Color(0xFF0B0F1D),
            Color(0xFF1A1930),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4DA6FF),
            Color(0xFF276DFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DA6FF).withOpacity(0.7),
            blurRadius: 18,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'B',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }
}

// Группировка задач по категориям, как в React-версии.
Map<String, List<Task>> _groupTasksByCategory(List<Task> tasks) {
  final Map<String, List<Task>> result = {};
  for (final task in tasks) {
    result.putIfAbsent(task.category, () => []).add(task);
  }
  return result;
}

Color _getCategoryColor(String category) {
  switch (category) {
    case 'Покупки':
      return const Color(0xFF8E5AFF);
    case 'Работа':
      return const Color(0xFFE05A5A);
    case 'Дом':
      return const Color(0xFF3FA7D6);
    case 'Здоровье':
      return const Color(0xFF4CAF50);
    case 'Дети':
      return const Color(0xFFFFA726);
    case 'Финансы':
      return const Color(0xFF26C6DA);
    default:
      return const Color(0xFF7E7E8A);
  }
}

String _getCategoryTitle(String category) {
  switch (category) {
    case 'Покупки':
      return 'Shopping';
    case 'Работа':
      return 'Work';
    case 'Дом':
      return 'Home';
    case 'Здоровье':
      return 'Health';
    case 'Дети':
      return 'Kids';
    case 'Финансы':
      return 'Finance';
    default:
      return category;
  }
}
