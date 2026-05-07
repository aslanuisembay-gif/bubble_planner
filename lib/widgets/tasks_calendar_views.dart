import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../translations.dart';

DateTime mondayOfWeek(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

Map<DateTime, List<BubbleTaskItem>> tasksGroupedByCalendarDay(
  List<BubbleTaskItem> tasks,
  AppState state,
) {
  final m = <DateTime, List<BubbleTaskItem>>{};
  for (final t in tasks) {
    final k = state.calendarDayStart(t.dueAt);
    m.putIfAbsent(k, () => []).add(t);
  }
  return m;
}

int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

String _weekdayShortLabel(String locale, int indexFromMonday) {
  final d = DateTime(2024, 1, 1 + indexFromMonday);
  final s = DateFormat.E(locale).format(d);
  return s.length > 2 ? s.substring(0, 2) : s;
}

/// Неделя: сетка дней как у месяца; тап по дню раскрывает список задач вниз.
class TasksWeekCalendarStrip extends StatelessWidget {
  const TasksWeekCalendarStrip({
    super.key,
    required this.weekStartMonday,
    required this.tasks,
    required this.state,
    required this.lang,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.taskTileBuilder,
    required this.expandedDay,
    required this.onDayToggle,
  });

  final DateTime weekStartMonday;
  final List<BubbleTaskItem> tasks;
  final AppState state;
  final String lang;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final Widget Function(BubbleTaskItem task) taskTileBuilder;
  /// Выбранный день (любая дата в этот календарный день) или `null`, если панель закрыта.
  final DateTime? expandedDay;
  final void Function(DateTime day) onDayToggle;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    final a = bp.talkAccent;
    final grouped = tasksGroupedByCalendarDay(tasks, state);
    final end = weekStartMonday.add(const Duration(days: 6));
    final rangeStr =
        '${DateFormat.MMMd(lang).format(weekStartMonday)} – ${DateFormat.MMMd(lang).format(end)}';
    final expandedKey = expandedDay == null ? null : state.calendarDayStart(expandedDay!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onPrevWeek,
                icon: Icon(Icons.chevron_left_rounded, color: bp.textPrimary, size: 22),
              ),
              Expanded(
                child: Text(
                  '${tr('calendarWeekTitle', lang: lang)} · $rangeStr',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: bp.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onNextWeek,
                icon: Icon(Icons.chevron_right_rounded, color: bp.textPrimary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    _weekdayShortLabel(lang, i),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bp.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
            ),
            itemCount: 7,
            itemBuilder: (context, i) {
              final day = weekStartMonday.add(Duration(days: i));
              final ck = state.calendarDayStart(day);
              final list = grouped[ck] ?? [];
              final n = list.length;
              final today = _today();
              final isToday =
                  day.year == today.year && day.month == today.month && day.day == today.day;
              final isSelected = expandedKey != null && expandedKey == ck;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onDayToggle(day),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? a.withValues(alpha: 0.14)
                          : (isToday ? a.withValues(alpha: 0.16) : bp.listCardFill),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? a
                            : (isToday ? a.withValues(alpha: 0.5) : bp.listCardBorder),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: bp.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        if (n > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var k = 0; k < (n > 3 ? 3 : n); k++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: a,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              if (n > 3)
                                Text(
                                  '+',
                                  style: TextStyle(
                                    color: a,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expandedKey == null
                ? const SizedBox(width: double.infinity)
                : _WeekExpandedTasksPanel(
                    day: expandedKey,
                    dayTasks: grouped[expandedKey] ?? <BubbleTaskItem>[],
                    bp: bp,
                    accent: a,
                    lang: lang,
                    taskTileBuilder: taskTileBuilder,
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeekExpandedTasksPanel extends StatelessWidget {
  const _WeekExpandedTasksPanel({
    required this.day,
    required this.dayTasks,
    required this.bp,
    required this.accent,
    required this.lang,
    required this.taskTileBuilder,
  });

  final DateTime day;
  final List<BubbleTaskItem> dayTasks;
  final BubblePlannerColors bp;
  final Color accent;
  final String lang;
  final Widget Function(BubbleTaskItem task) taskTileBuilder;

  @override
  Widget build(BuildContext context) {
    final sorted = List<BubbleTaskItem>.from(dayTasks)
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final title = DateFormat.yMMMEd(lang).format(day);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        decoration: BoxDecoration(
          color: bp.listCardFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: bp.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (sorted.isNotEmpty)
                  Text(
                    '${sorted.length}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  tr('noTasks', lang: lang),
                  style: TextStyle(color: bp.listTextMuted, fontSize: 13),
                ),
              )
            else
              for (var j = 0; j < sorted.length; j++) ...[
                if (j > 0) const SizedBox(height: 6),
                taskTileBuilder(sorted[j]),
              ],
          ],
        ),
      ),
    );
  }
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Сетка месяца с точками по числу задач; тап по дню — список задач.
class TasksMonthCalendarGrid extends StatelessWidget {
  const TasksMonthCalendarGrid({
    super.key,
    required this.monthStart,
    required this.tasks,
    required this.state,
    required this.lang,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime monthStart;
  final List<BubbleTaskItem> tasks;
  final AppState state;
  final String lang;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    final a = bp.talkAccent;
    final y = monthStart.year;
    final m = monthStart.month;
    final first = DateTime(y, m, 1);
    final dim = _daysInMonth(y, m);
    final leading = first.weekday - DateTime.monday;
    final grouped = tasksGroupedByCalendarDay(tasks, state);
    final title = DateFormat.yMMMM(lang).format(first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onPrevMonth,
                icon: Icon(Icons.chevron_left_rounded, color: bp.textPrimary, size: 22),
              ),
              Expanded(
                child: Text(
                  '${tr('calendarMonthTitle', lang: lang)} · $title',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: bp.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onNextMonth,
                icon: Icon(Icons.chevron_right_rounded, color: bp.textPrimary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    _weekdayShortLabel(lang, i),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bp.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
            ),
            itemCount: ((leading + dim + 6) ~/ 7) * 7,
            itemBuilder: (context, index) {
              final dayNum = index - leading + 1;
              if (index < leading || dayNum < 1 || dayNum > dim) {
                return const SizedBox.shrink();
              }
              final day = DateTime(y, m, dayNum);
              final ck = state.calendarDayStart(day);
              final list = grouped[ck] ?? [];
              final n = list.length;
              final today = _today();
              final isToday = day.year == today.year && day.month == today.month && day.day == today.day;

              return InkWell(
                onTap: n == 0
                    ? null
                    : () => _showDayTasks(context, lang, day, list),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday ? a.withValues(alpha: 0.16) : bp.listCardFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday ? a.withValues(alpha: 0.5) : bp.listCardBorder,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          color: bp.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      if (n > 0) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var k = 0; k < (n > 3 ? 3 : n); k++)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: a,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            if (n > 3)
                              Text(
                                '+',
                                style: TextStyle(
                                  color: a,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _showDayTasks(
  BuildContext context,
  String lang,
  DateTime day,
  List<BubbleTaskItem> list,
) async {
  final bp = context.bp;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: bp.modalSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final h = (MediaQuery.sizeOf(ctx).height * 0.48).clamp(260.0, 520.0);
      return SafeArea(
        child: SizedBox(
          height: h,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DateFormat.yMMMEd(lang).format(day),
                  style: TextStyle(
                    color: bp.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: bp.listCardBorder),
                    itemBuilder: (_, i) {
                      final t = list[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t.title,
                          style: TextStyle(color: bp.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          t.categoryTag,
                          style: TextStyle(color: bp.textSecondary, fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
