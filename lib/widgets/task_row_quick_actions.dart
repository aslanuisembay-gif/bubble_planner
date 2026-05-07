import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../translations.dart' show tr, trFill;
import 'task_share_sheets.dart';

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
    this.onBulkModeForSheets,
    this.sheetUniverseTaskIds,
    this.sheetAllLabelKey = 'shareAllTasks',
  });

  final BubbleTaskItem task;
  final BuildContext hostContext;
  /// Called first on every tap (e.g. close inline menu or pop bottom sheet).
  final VoidCallback onBeforeAction;
  final void Function(bool bulkMode)? onBulkModeForSheets;
  final Set<String>? sheetUniverseTaskIds;
  final String sheetAllLabelKey;

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

    void afterMenuClose(VoidCallback fn) {
      onBeforeAction();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hostContext.mounted) fn();
      });
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
              afterMenuClose(() => showEditTaskTitleDialog(hostContext, task));
            }),
            const SizedBox(width: 6),
            slot(Icons.autorenew_rounded, tr('tooltipRepeat', lang: lang), () {
              afterMenuClose(() => showRecurrenceWeekdayPicker(hostContext, task));
            }),
            const SizedBox(width: 6),
            slot(Icons.schedule_rounded, tr('tooltipSchedule', lang: lang), () {
              afterMenuClose(() => pickTaskDateAndTime(hostContext, task.id));
            }),
            const SizedBox(width: 6),
            slot(Icons.notifications_outlined, tr('tooltipReminder', lang: lang), () {
              afterMenuClose(
                () => showReminderOffsetSheet(
                  hostContext,
                  task,
                  messengerContext: hostContext,
                ),
              );
            }),
            const SizedBox(width: 6),
            slot(Icons.ios_share_rounded, tr('tooltipShareRow', lang: lang), () {
              onBeforeAction();
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!hostContext.mounted) return;
                final allowPick = onBulkModeForSheets != null;
                await runTasksListShareFlow(
                  hostContext,
                  setBulkMode: onBulkModeForSheets ?? (_) {},
                  anchorTaskId: task.id,
                  universeIds: sheetUniverseTaskIds,
                  allowPickWithCheckmarks: allowPick,
                  allLabelKey: sheetAllLabelKey,
                );
              });
            }),
            const SizedBox(width: 6),
            slot(Icons.delete_outline_rounded, tr('tooltipDelete', lang: lang), () {
              onBeforeAction();
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!hostContext.mounted) return;
                final allowPick = onBulkModeForSheets != null;
                await runTasksListDeleteFlow(
                  hostContext,
                  setBulkMode: onBulkModeForSheets ?? (_) {},
                  anchorTaskId: task.id,
                  universeIds: sheetUniverseTaskIds,
                  allowPickWithCheckmarks: allowPick,
                  allLabelKey: sheetAllLabelKey,
                );
              });
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
        autocorrect: true,
        enableSuggestions: true,
        smartDashesType: SmartDashesType.enabled,
        smartQuotesType: SmartQuotesType.enabled,
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

/// Дата и время — карусель как в будильнике iOS ([CupertinoDatePicker]).
Future<void> pickTaskDateAndTime(BuildContext context, String taskId) async {
  final state = context.read<AppState>();
  BubbleTaskItem? task;
  for (final x in state.tasks) {
    if (x.id == taskId) {
      task = x;
      break;
    }
  }
  if (task == null) return;

  var selected = task.dueAt;
  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final lang = ctx.watch<AppState>().languageCode;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(tr('cancel', lang: lang)),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: Text(
                        tr('save', lang: lang),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: Color(0xFFE5E5EA),
                          fontSize: 22,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.dateAndTime,
                      initialDateTime: selected,
                      minimumDate: DateTime(2020, 1, 1),
                      maximumDate: DateTime(2035, 12, 31, 23, 59),
                      use24hFormat: true,
                      minuteInterval: 1,
                      onDateTimeChanged: (d) => selected = d,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (picked == null || !context.mounted) return;
  if (state.tasks.indexWhere((e) => e.id == taskId) < 0) return;
  state.updateTaskDue(taskId, picked);
}

List<String> _weekdayLabels(String lang) {
  if (lang == 'ru') {
    return const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  }
  return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
}

Future<void> showRecurrenceWeekdayPicker(BuildContext context, BubbleTaskItem task) async {
  final state = context.read<AppState>();
  final lang = state.languageCode;
  final labels = _weekdayLabels(lang);
  const ruDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final selected = <int>{};
  final cur = task.recurrenceDays;
  if (cur != null) {
    for (final d in cur) {
      var i = labels.indexOf(d);
      if (i < 0) i = ruDays.indexOf(d);
      if (i < 0) i = enDays.indexOf(d);
      if (i >= 0) selected.add(i);
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('repeatPickDays', lang: lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        FilterChip(
                          label: Text(labels[i]),
                          selected: selected.contains(i),
                          onSelected: (v) {
                            setModalState(() {
                              if (v) {
                                selected.add(i);
                              } else {
                                selected.remove(i);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(tr('cancel', lang: lang), style: const TextStyle(color: Colors.white70)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          state.updateTaskRecurrence(task.id, null);
                          Navigator.pop(ctx);
                        },
                        child: Text(tr('repeatClear', lang: lang), style: const TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          if (selected.isEmpty) {
                            state.updateTaskRecurrence(task.id, null);
                          } else {
                            final order = selected.toList()..sort();
                            state.updateTaskRecurrence(
                              task.id,
                              order.map((j) => labels[j]).toList(),
                            );
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text(tr('apply', lang: lang)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

String _reminderChipLabel(int minutes, String lang) {
  switch (minutes) {
    case 5:
      return tr('reminderBefore5', lang: lang);
    case 30:
      return tr('reminderBefore30', lang: lang);
    case 60:
      return tr('reminderBefore60', lang: lang);
    default:
      return '$minutes';
  }
}

Future<void> showReminderOffsetSheet(
  BuildContext context,
  BubbleTaskItem t, {
  BuildContext? messengerContext,
}) async {
  final state = context.read<AppState>();
  final lang = state.languageCode;
  final snackCtx = messengerContext ?? context;
  const opts = [5, 30, 60];
  final selected = <int>{
    for (final o in t.reminderOffsets ?? const <int>[])
      if (opts.contains(o)) o,
  };

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('tooltipReminder', lang: lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in opts)
                        FilterChip(
                          label: Text(_reminderChipLabel(m, lang)),
                          selected: selected.contains(m),
                          onSelected: (v) {
                            setModalState(() {
                              if (v) {
                                selected.add(m);
                              } else {
                                selected.remove(m);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(tr('cancel', lang: lang), style: const TextStyle(color: Colors.white70)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setModalState(() => selected.clear());
                        },
                        child: Text(tr('clearReminder', lang: lang), style: const TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final list = selected.toList()..sort();
                          state.updateTaskReminderOffsets(t.id, list);
                          Navigator.pop(ctx);
                          if (snackCtx.mounted) {
                            final ms = ScaffoldMessenger.maybeOf(snackCtx);
                            if (list.isEmpty) {
                              ms?.showSnackBar(
                                SnackBar(content: Text(tr('clearReminder', lang: lang))),
                              );
                            } else {
                              ms?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    trFill('remindersSaved', {
                                      's': list.join(', '),
                                    }, lang: lang),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(tr('apply', lang: lang)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
