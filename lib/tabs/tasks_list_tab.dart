import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/task_row_quick_actions.dart';

class TasksListTab extends StatefulWidget {
  const TasksListTab({super.key});

  @override
  State<TasksListTab> createState() => _TasksListTabState();
}

class _TasksListTabState extends State<TasksListTab> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _bulkMode = false;
  /// Which task row shows the inline action bar (three-dot menu).
  String? _menuOpenForTaskId;

  static const _purple = Color(0xFF8B5CF6);
  static const _gold = Color(0xFFFBBF24);
  static const _menuHighlight = Color(0xFF38BDF8);
  static const _timeRed = Color(0xFFE53935);

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final all = state.tasksForListView();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayTasks = all.where((t) => state.isSameCalendarDay(t.dueAt, todayStart)).toList();
    final following = all.where((t) => !state.isSameCalendarDay(t.dueAt, todayStart)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Spacer(),
              _circleIcon(Icons.search_rounded, () => _searchFocus.requestFocus()),
              const SizedBox(width: 8),
              _circleIcon(Icons.settings_rounded, () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const SettingsSheet(),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Tasks',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Done: ${state.doneCount}',
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Active: ${state.activeCount}',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              _headerAction(Icons.ios_share_rounded, () {
                final text = state.tasks.map((t) => t.title).join('\n');
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All tasks copied')),
                );
              }),
              _headerAction(Icons.delete_outline_rounded, () {
                if (state.selectedTaskIds.isNotEmpty) {
                  state.deleteTasksByIds(state.selectedTaskIds);
                } else {
                  state.deleteTasksByIds(state.tasks.map((e) => e.id));
                }
                setState(() => _bulkMode = false);
              }),
              const SizedBox(width: 6),
              Material(
                color: _purple,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openQuickAdd(context),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _headerAction(Icons.close_rounded, () {
                state.clearSelection();
                setState(() => _bulkMode = false);
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _search,
            focusNode: _searchFocus,
            onChanged: (v) => context.read<AppState>().setSearchQuery(v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search tasks or categories...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _chip(context, 'All', TaskListFilter.all, state.listFilter == TaskListFilter.all),
              const SizedBox(width: 8),
              _chip(context, 'Active', TaskListFilter.active, state.listFilter == TaskListFilter.active),
              const SizedBox(width: 8),
              _chip(context, 'Done', TaskListFilter.done, state.listFilter == TaskListFilter.done),
            ],
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
                  if (todayTasks.isNotEmpty) ...[
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            'TODAY',
                            style: TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_bulkMode)
                          TextButton(
                            onPressed: () => state.selectAllVisible(todayTasks.map((e) => e.id)),
                            child: const Text('SELECT ALL', style: TextStyle(color: _purple)),
                          ),
                      ],
                    ),
                    for (final t in todayTasks) _taskCard(context, state, t),
                  ],
                  if (following.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                      child: Text(
                        'FOLLOWING DAYS',
                        style: TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    for (final t in following) _taskCard(context, state, t),
                  ],
                  if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No tasks',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
                          onPressed: () {
                            final txt = state.shareTextForTasks(state.selectedTaskIds);
                            Clipboard.setData(ClipboardData(text: txt));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Share Selected (${state.selectedTaskIds.length})'),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.ios_share_rounded, size: 20),
                          label: Text(
                            'Share Selected (${state.selectedTaskIds.length})',
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
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Cancel Selection'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  Widget _headerAction(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, TaskListFilter f, bool on) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<AppState>().setListFilter(f),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? _purple : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: on ? 0.0 : 0.1)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskCard(BuildContext context, AppState state, BubbleTaskItem t) {
    final dueLineColor = t.isDone ? Colors.white38 : _timeRed;
    final menuOpen = _menuOpenForTaskId == t.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (menuOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: TaskQuickActionsRow(
                    task: t,
                    hostContext: context,
                    onBeforeAction: () => setState(() => _menuOpenForTaskId = null),
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                SizedBox(
                  width: 128,
                  child: Text(
                    state.formatDueLineCompact(t.dueAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dueLineColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (t.reminderAt != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: _menuHighlight.withValues(alpha: t.isDone ? 0.4 : 1),
                    ),
                  ),
                Expanded(
                  child: Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.isDone ? const Color(0xFF22C55E) : Colors.white,
                      fontWeight: FontWeight.w700,
                      decoration: t.isDone ? TextDecoration.lineThrough : null,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (t.recurrenceDays != null && t.recurrenceDays!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 72),
                      child: Text(
                        t.recurrenceDays!.join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _purple.withValues(alpha: t.isDone ? 0.45 : 0.95),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t.categoryTag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: t.isDone ? 0.45 : 0.75),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (menuOpen) {
                            setState(() => _menuOpenForTaskId = null);
                          } else {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() => _menuOpenForTaskId = t.id);
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: menuOpen
                                  ? _menuHighlight.withValues(alpha: 0.35)
                                  : Colors.transparent,
                            ),
                            child: Icon(
                              Icons.more_vert,
                              color: menuOpen ? Colors.white : Colors.white54,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () {
                        if (_bulkMode) {
                          context.read<AppState>().toggleTaskSelection(t.id);
                        } else {
                          context.read<AppState>().toggleTaskDone(t.id);
                        }
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _bulkMode && state.selectedTaskIds.contains(t.id)
                                ? _purple
                                : Colors.white54,
                            width: 2,
                          ),
                          color: _bulkMode
                              ? (state.selectedTaskIds.contains(t.id)
                                  ? _purple
                                  : Colors.transparent)
                              : (t.isDone ? const Color(0xFF22C55E) : Colors.transparent),
                        ),
                        child: () {
                          final showCheck = _bulkMode
                              ? state.selectedTaskIds.contains(t.id)
                              : t.isDone;
                          return showCheck
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : null;
                        }(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openQuickAdd(BuildContext context) {
    final c = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1520),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add a task...',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        final text = c.text.trim();
                        if (text.isNotEmpty) {
                          context.read<AppState>().addTaskFromText(text);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
