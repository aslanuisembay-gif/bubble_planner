import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../translations.dart';

/// Horizontal action bar (edit, repeat, schedule, reminder, share, delete) — matches list / sheet UX.
///
/// [hostContext] must be a long-lived context (e.g. the task row / sheet tile). Do not use only
/// this widget's [context]: after [onBeforeAction] the action row may be disposed and its context
/// becomes invalid for [showDialog] / pickers / [ScaffoldMessenger].
class TaskQuickActionsRow extends StatelessWidget {
  const TaskQuickActionsRow({
    super.key,
    required this.task,
    required this.hostContext,
    required this.onBeforeAction,
  });

  final BubbleTaskItem task;
  final BuildContext hostContext;
  /// Called first on every tap (e.g. close inline menu or pop bottom sheet).
  final VoidCallback onBeforeAction;

  @override
  Widget build(BuildContext context) {
    final state = hostContext.watch<AppState>();
    final lang = state.languageCode;

    Widget slot(IconData icon, String tooltip, VoidCallback onTap) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            // Явная зона нажатия (раньше overflow Stack «съедал» касания).
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF121016).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            slot(Icons.edit_outlined, tr('tooltipEdit', lang: lang), () {
              onBeforeAction();
              showEditTaskTitleDialog(hostContext, task);
            }),
            const SizedBox(width: 6),
            slot(Icons.autorenew_rounded, tr('tooltipRepeat', lang: lang), () {
              onBeforeAction();
              state.toggleTaskRecurrencePreset(task.id);
            }),
            const SizedBox(width: 6),
            slot(Icons.schedule_rounded, tr('tooltipSchedule', lang: lang), () {
              onBeforeAction();
              showScheduleChoiceSheet(hostContext, task.id);
            }),
            const SizedBox(width: 6),
            slot(Icons.notifications_outlined, tr('tooltipReminder', lang: lang), () {
              onBeforeAction();
              pickTaskReminder(hostContext, task);
            }),
            const SizedBox(width: 6),
            slot(Icons.ios_share_rounded, tr('tooltipShareRow', lang: lang), () {
              onBeforeAction();
              final line =
                  '${state.formatDueLineCompact(task.dueAt)} — ${task.title}';
              Clipboard.setData(ClipboardData(text: line));
              ScaffoldMessenger.of(hostContext).showSnackBar(
                SnackBar(content: Text(tr('taskCopiedToast', lang: lang))),
              );
            }),
            const SizedBox(width: 6),
            slot(Icons.delete_outline_rounded, tr('tooltipDelete', lang: lang), () {
              onBeforeAction();
              state.deleteTask(task.id);
            }),
          ],
        ),
      ),
    );
  }
}

Future<void> showEditTaskTitleDialog(BuildContext context, BubbleTaskItem t) async {
  final newTitle = await showDialog<String?>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => _EditTaskTitleDialog(initialTitle: t.title),
  );
  if (newTitle != null && newTitle.isNotEmpty && context.mounted) {
    context.read<AppState>().updateTaskTitle(t.id, newTitle);
  }
}

class _EditTaskTitleDialog extends StatefulWidget {
  const _EditTaskTitleDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_EditTaskTitleDialog> createState() => _EditTaskTitleDialogState();
}

class _EditTaskTitleDialogState extends State<_EditTaskTitleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1B24),
      title: Text(tr('taskEditTitle', lang: lang), style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.white),
        autofocus: true,
        decoration: InputDecoration(
          hintText: tr('editTaskHint', lang: lang),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel', lang: lang))),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(tr('save', lang: lang)),
        ),
      ],
    );
  }
}

Future<void> pickTaskDate(BuildContext context, String taskId) async {
  final state = context.read<AppState>();
  BubbleTaskItem? task;
  for (final x in state.tasks) {
    if (x.id == taskId) {
      task = x;
      break;
    }
  }
  if (task == null) return;
  final d = await showDatePicker(
    context: context,
    useRootNavigator: true,
    initialDate: task.dueAt,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (d == null || !context.mounted) return;
  final i = state.tasks.indexWhere((e) => e.id == taskId);
  if (i < 0) return;
  final latest = state.tasks[i];
  state.updateTaskDue(
    taskId,
    DateTime(d.year, d.month, d.day, latest.dueAt.hour, latest.dueAt.minute),
  );
}

Future<void> pickTaskTime(BuildContext context, String taskId) async {
  final state = context.read<AppState>();
  BubbleTaskItem? task;
  for (final x in state.tasks) {
    if (x.id == taskId) {
      task = x;
      break;
    }
  }
  if (task == null) return;
  final picked = await showTimePicker(
    context: context,
    useRootNavigator: true,
    initialTime: TimeOfDay(hour: task.dueAt.hour, minute: task.dueAt.minute),
  );
  if (picked == null || !context.mounted) return;
  final i = state.tasks.indexWhere((e) => e.id == taskId);
  if (i < 0) return;
  final latest = state.tasks[i];
  state.updateTaskDue(
    taskId,
    DateTime(
      latest.dueAt.year,
      latest.dueAt.month,
      latest.dueAt.day,
      picked.hour,
      picked.minute,
    ),
  );
}

Future<void> showScheduleChoiceSheet(BuildContext context, String taskId) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: const Color(0xFF1A1520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final lang = ctx.watch<AppState>().languageCode;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined, color: Colors.white70),
              title: Text(tr('changeDateTitle', lang: lang), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) pickTaskDate(context, taskId);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded, color: Colors.white70),
              title: Text(tr('changeTimeTitle', lang: lang), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) pickTaskTime(context, taskId);
                });
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> pickTaskReminder(BuildContext context, BubbleTaskItem t) async {
  final state = context.read<AppState>();
  final i0 = state.tasks.indexWhere((e) => e.id == t.id);
  if (i0 < 0) return;
  final current = state.tasks[i0];
  final base = current.reminderAt ?? current.dueAt;
  final d = await showDatePicker(
    context: context,
    useRootNavigator: true,
    initialDate: base,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (d == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    useRootNavigator: true,
    initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
  );
  if (time == null || !context.mounted) return;
  final at = DateTime(d.year, d.month, d.day, time.hour, time.minute);
  if (state.tasks.indexWhere((e) => e.id == t.id) < 0) return;
  state.updateTaskReminder(t.id, at);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${tr('reminderSet', lang: state.languageCode)} ${state.formatDueTime(at)}'),
    ),
  );
}
