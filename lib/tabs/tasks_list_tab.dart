import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../translations.dart';
import '../widgets/movable_add_fab.dart';
import '../widgets/planner_settings_sheet.dart';
import '../widgets/sticky_note_add_task_sheet.dart';
import '../widgets/task_share_sheets.dart';
import '../widgets/tasks_calendar_views.dart';
import '../widgets/unified_task_row.dart';

class TasksListTab extends StatefulWidget {
  const TasksListTab({super.key});

  @override
  State<TasksListTab> createState() => _TasksListTabState();
}

class _TasksListTabState extends State<TasksListTab> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _bulkMode = false;
  bool _searchExpanded = false;
  /// Which task row shows the inline action bar (three-dot menu).
  String? _menuOpenForTaskId;
  late DateTime _weekStartMonday;
  late DateTime _monthPage;
  /// Раскрытый день в недельном календаре (`null` — панель задач скрыта).
  DateTime? _weekExpandedDay;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    _weekStartMonday = mondayOfWeek(d);
    _monthPage = DateTime(n.year, n.month, 1);
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
    final accent = bp.talkAccent;
    final warn = bp.warning;
    final showCalendarOnly = state.tasksCalendarMode != TasksCalendarMode.day;

    final all = state.tasksForListView();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayTasks = all.where((t) => state.isSameCalendarDay(t.dueAt, todayStart)).toList();
    final futureFollowing =
        all.where((t) => state.isFutureCalendarDayTask(t, todayStart)).toList();
    final earlierPastDone = all.where((t) {
      if (t.id.startsWith('rt_')) return false;
      return state.calendarDayStart(t.dueAt).isBefore(todayStart) && t.isDone;
    }).toList();
    final attentionTasks =
        all.where((t) => state.isAttentionOverdueTask(t, todayStart)).toList();
    const attentionSectionColor = Color(0xFFFF6D4A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              const Spacer(),
              _headerAction(Icons.ios_share_rounded, () async {
                await runTasksListShareFlow(
                  context,
                  setBulkMode: (b) => setState(() => _bulkMode = b),
                );
              }),
              _headerAction(Icons.delete_outline_rounded, () async {
                await runTasksListDeleteFlow(
                  context,
                  setBulkMode: (b) => setState(() => _bulkMode = b),
                );
              }),
              _headerAction(Icons.close_rounded, () {
                final app = context.read<AppState>();
                _searchFocus.unfocus();
                _search.clear();
                app.setSearchQuery('');
                app.clearSelection();
                setState(() {
                  _menuOpenForTaskId = null;
                  _bulkMode = false;
                  _searchExpanded = false;
                });
              }),
              _circleIcon(
                context,
                state.themeMode == BubbleThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                () {
                  HapticFeedback.selectionClick();
                  final next = state.themeMode == BubbleThemeMode.dark
                      ? BubbleThemeMode.light
                      : BubbleThemeMode.dark;
                  context.read<AppState>().setThemeMode(next);
                },
              ),
              const SizedBox(width: 8),
              _circleIcon(
                context,
                Icons.search_rounded,
                () {
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
                      context.read<AppState>().setSearchQuery('');
                    }
                  });
                },
                selected: _searchExpanded,
              ),
              const SizedBox(width: 8),
              _circleIcon(context, Icons.settings_rounded, () {
                showPlannerSettings(context);
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('tasksTitle', lang: state.languageCode),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: bp.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipGroup(
                  context,
                  children: [
                    _controlChip(
                      context,
                      tr('calendarDayMode', lang: state.languageCode),
                      state.tasksCalendarMode == TasksCalendarMode.day,
                      compact: true,
                      onTap: () {
                        context.read<AppState>().setTasksCalendarMode(TasksCalendarMode.day);
                        setState(() => _weekExpandedDay = null);
                      },
                    ),
                    const SizedBox(width: 4),
                    _controlChip(
                      context,
                      tr('calendarWeekViewToggle', lang: state.languageCode),
                      state.tasksCalendarMode == TasksCalendarMode.week,
                      compact: true,
                      onTap: () {
                        context.read<AppState>().setTasksCalendarMode(TasksCalendarMode.week);
                      },
                    ),
                    const SizedBox(width: 4),
                    _controlChip(
                      context,
                      tr('calendarMonthViewToggle', lang: state.languageCode),
                      state.tasksCalendarMode == TasksCalendarMode.month,
                      compact: true,
                      onTap: () {
                        context.read<AppState>().setTasksCalendarMode(TasksCalendarMode.month);
                        setState(() => _weekExpandedDay = null);
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                _chipGroup(
                  context,
                  children: [
                    _controlChip(
                      context,
                      tr('filterActive', lang: state.languageCode),
                      state.listFilter == TaskListFilter.active,
                      compact: true,
                      onTap: () => context.read<AppState>().setListFilter(TaskListFilter.active),
                    ),
                    const SizedBox(width: 4),
                    _controlChip(
                      context,
                      tr('filterDone', lang: state.languageCode),
                      state.listFilter == TaskListFilter.done,
                      compact: true,
                      onTap: () => context.read<AppState>().setListFilter(TaskListFilter.done),
                    ),
                    const SizedBox(width: 4),
                    _controlChip(
                      context,
                      tr('filterAll', lang: state.languageCode),
                      state.listFilter == TaskListFilter.all,
                      compact: true,
                      onTap: () => context.read<AppState>().setListFilter(TaskListFilter.all),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                _routinesSwitchChip(
                  context,
                  label: tr('tasksToggleRoutinesShort', lang: state.languageCode),
                  value: state.dailyRoutinesEnabled,
                  onChanged: (v) => context.read<AppState>().toggleDailyRoutines(v),
                ),
              ],
            ),
          ),
        ),
        if (_searchExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (v) {
                context.read<AppState>().setSearchQuery(v);
                setState(() {});
              },
              style: TextStyle(color: bp.textPrimary),
              decoration: InputDecoration(
                hintText: tr('searchPlaceholder', lang: state.languageCode),
                hintStyle: TextStyle(color: bp.textSecondary.withValues(alpha: 0.75)),
                prefixIcon: Icon(Icons.search, color: bp.listIconMuted),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          context.read<AppState>().setSearchQuery('');
                          setState(() {});
                        },
                        icon: Icon(Icons.close_rounded, color: bp.listIconMuted),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (_menuOpenForTaskId != null &&
                        (n is ScrollUpdateNotification || n is UserScrollNotification)) {
                      setState(() => _menuOpenForTaskId = null);
                    }
                    return false;
                  },
                  child: ListView(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                  children: [
                  if (state.tasksCalendarMode == TasksCalendarMode.week)
                    TasksWeekCalendarStrip(
                      weekStartMonday: _weekStartMonday,
                      tasks: all,
                      state: state,
                      lang: state.languageCode,
                      expandedDay: _weekExpandedDay,
                      onDayToggle: (day) {
                        setState(() {
                          final k = state.calendarDayStart(day);
                          final cur = _weekExpandedDay == null
                              ? null
                              : state.calendarDayStart(_weekExpandedDay!);
                          if (cur == k) {
                            _weekExpandedDay = null;
                          } else {
                            _weekExpandedDay = day;
                          }
                        });
                      },
                      onPrevWeek: () {
                        setState(() {
                          _weekStartMonday = _weekStartMonday.subtract(const Duration(days: 7));
                          _weekExpandedDay = null;
                        });
                      },
                      onNextWeek: () {
                        setState(() {
                          _weekStartMonday = _weekStartMonday.add(const Duration(days: 7));
                          _weekExpandedDay = null;
                        });
                      },
                      taskTileBuilder: (t) => _taskRow(
                        context,
                        state,
                        t,
                        attentionHighlight: state.isAttentionOverdueTask(t, todayStart),
                      ),
                    ),
                  if (state.tasksCalendarMode == TasksCalendarMode.month)
                    TasksMonthCalendarGrid(
                      monthStart: _monthPage,
                      tasks: all,
                      state: state,
                      lang: state.languageCode,
                      onPrevMonth: () {
                        setState(() {
                          final p = _monthPage;
                          _monthPage = DateTime(p.year, p.month - 1, 1);
                        });
                      },
                      onNextMonth: () {
                        setState(() {
                          final p = _monthPage;
                          _monthPage = DateTime(p.year, p.month + 1, 1);
                        });
                      },
                    ),
                  if (!showCalendarOnly && todayTasks.isNotEmpty) ...[
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            tr('todaySection', lang: state.languageCode),
                            style: TextStyle(
                              color: warn,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.85,
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_bulkMode)
                          TextButton(
                            onPressed: () => state.selectAllVisible(todayTasks.map((e) => e.id)),
                            child: Text(
                              tr('selectAll', lang: state.languageCode),
                              style: TextStyle(color: accent),
                            ),
                          ),
                      ],
                    ),
                    for (final t in todayTasks) _taskRow(context, state, t),
                  ],
                  if (!showCalendarOnly && futureFollowing.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                      child: Text(
                        tr('followingDaysSection', lang: state.languageCode),
                        style: TextStyle(
                          color: warn,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.85,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                    for (final t in futureFollowing) _taskRow(context, state, t),
                  ],
                  if (!showCalendarOnly && attentionTasks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                      child: Text(
                        tr('needsAttentionSection', lang: state.languageCode),
                        style: const TextStyle(
                          color: attentionSectionColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.85,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                    for (final t in attentionTasks)
                      _taskRow(context, state, t, attentionHighlight: true),
                  ],
                  if (!showCalendarOnly && earlierPastDone.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                      child: Text(
                        tr('earlierSection', lang: state.languageCode),
                        style: TextStyle(
                          color: warn,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.85,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                    for (final t in earlierPastDone) _taskRow(context, state, t),
                  ],
                  if (!showCalendarOnly && all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        tr('noTasks', lang: state.languageCode),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: bp.listTextMuted),
                      ),
                    ),
                  ],
                  ),
                ),
              if (_bulkMode && state.selectedTaskIds.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final txt = state.shareTextForTasks(state.selectedTaskIds);
                            if (txt.isEmpty) return;
                            final ch = await showShareChannelSheet(context);
                            if (!context.mounted || ch == null) return;
                            await dispatchTaskShare(context, ch, txt);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: bp.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: Icon(Icons.ios_share_rounded, size: 20, color: bp.onPrimary),
                          label: Text(
                            trFill('shareSelected', {'n': '${state.selectedTaskIds.length}'},
                                lang: state.languageCode),
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
                            state.deleteTasksByIds(state.selectedTaskIds);
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
                            '${tr('delete', lang: state.languageCode)} (${state.selectedTaskIds.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {
                            state.clearSelection();
                            setState(() => _bulkMode = false);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: bp.textPrimary,
                            side: BorderSide(color: bp.listCardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(tr('cancelSelection', lang: state.languageCode)),
                        ),
                      ),
                    ],
                  ),
                ),
              MovableAddFab(
                storageKey: 'tasks_list',
                onPressed: () => showStickyNoteAddTaskSheet(context),
                accent: accent,
                onPrimary: bp.onPrimary,
                minBottom: 8,
                bottomReserved:
                    _bulkMode && state.selectedTaskIds.isNotEmpty ? 130 : 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskRow(
    BuildContext context,
    AppState state,
    BubbleTaskItem t, {
    bool attentionHighlight = false,
  }) {
    return UnifiedTaskRow(
      task: t,
      menuOpen: _menuOpenForTaskId == t.id,
      bulkMode: _bulkMode,
      selectedInBulk: state.selectedTaskIds.contains(t.id),
      onBulkModeForSheets: (b) => setState(() => _bulkMode = b),
      attentionHighlight: attentionHighlight,
      onMenuTap: () {
        if (_menuOpenForTaskId == t.id) {
          setState(() => _menuOpenForTaskId = null);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _menuOpenForTaskId = t.id);
          });
        }
      },
      onCheckTap: () {
        if (_bulkMode) {
          context.read<AppState>().toggleTaskSelection(t.id);
        } else {
          context.read<AppState>().toggleTaskDone(t.id);
        }
      },
      onQuickActionDone: () => setState(() => _menuOpenForTaskId = null),
    );
  }

  Widget _circleIcon(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    bool selected = false,
  }) {
    final bp = context.bp;
    final a = bp.talkAccent;
    return Material(
      color: selected ? a.withValues(alpha: 0.22) : bp.listCardFill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: selected ? a : bp.listIconMuted,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _controlChip(
    BuildContext context,
    String label,
    bool on, {
    bool compact = false,
    required VoidCallback onTap,
  }) {
    final bp = context.bp;
    final a = bp.talkAccent;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: on ? a : bp.listCardFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? Colors.transparent : bp.listCardBorder),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: on ? bp.onPrimary : bp.textPrimary,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            fontSize: compact ? 11 : 13,
          ),
        ),
      ),
    );
  }

  Widget _chipGroup(BuildContext context, {required List<Widget> children}) {
    final bp = context.bp;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bp.listCardFill.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bp.listCardBorder.withValues(alpha: 0.7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _routinesSwitchChip(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final bp = context.bp;
    final a = bp.talkAccent;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 3, 3),
      decoration: BoxDecoration(
        color: value ? a : bp.listCardFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: value ? Colors.transparent : bp.listCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: value ? bp.onPrimary : bp.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Transform.scale(
            scale: 0.68,
            alignment: Alignment.centerRight,
            child: Switch(
              value: value,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, VoidCallback onTap) {
    return Builder(
      builder: (context) {
        final bp = context.bp;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Material(
            color: bp.listCardFill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: bp.listIconMuted, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }

}
