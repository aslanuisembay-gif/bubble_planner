import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import 'task_row_quick_actions.dart';

/// Одна строка задачи: тот же вид, что на вкладке «Список», и в карточке категории из «Пузырей».
class UnifiedTaskRow extends StatelessWidget {
  const UnifiedTaskRow({
    super.key,
    required this.task,
    required this.menuOpen,
    required this.bulkMode,
    required this.selectedInBulk,
    required this.onMenuTap,
    required this.onCheckTap,
    required this.onQuickActionDone,
    /// Светлая карточка поверх градиента (вкладка «Список») — цвета из темы.
    /// `true` — карточка категории из «Пузырей» на светлом фоне: тёмный текст при глобальной тёмной теме.
    this.onLightTaskPanel = false,
    this.attentionHighlight = false,
    this.onBulkModeForSheets,
    this.sheetUniverseTaskIds,
    this.sheetAllLabelKey = 'shareAllTasks',
  });

  final BubbleTaskItem task;
  final bool menuOpen;
  final bool bulkMode;
  final bool selectedInBulk;
  final VoidCallback onMenuTap;
  final VoidCallback onCheckTap;
  final VoidCallback onQuickActionDone;
  final bool onLightTaskPanel;
  /// Просроченные невыполненные: розово-оранжевый акцент карточки.
  final bool attentionHighlight;
  final void Function(bool bulkMode)? onBulkModeForSheets;
  final Set<String>? sheetUniverseTaskIds;
  final String sheetAllLabelKey;

  static const Color _timeRed = Color(0xFFE53935);

  double _adaptiveTitleFontSize(String text) {
    final len = text.trim().length;
    if (len > 64) return 11.5;
    if (len > 42) return 12.2;
    if (len > 28) return 13.0;
    return 14.0;
  }

  double _adaptiveDueFontSize(String text, {required bool onLightTaskPanel}) {
    final len = text.trim().length;
    final base = onLightTaskPanel ? 13.0 : 12.0;
    if (len > 18) return base - 1.5;
    if (len > 14) return base - 1.0;
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bp = context.bp;
    final accent = bp.talkAccent;
    final hi = bp.primary;
    const darkOnCard = Color(0xFF111827);
    const mutedOnCard = Color(0xFF4B5563);
    final titleFg = onLightTaskPanel && bp.brightness == Brightness.dark
        ? (task.isDone ? const Color(0xFF16A34A) : darkOnCard)
        : (task.isDone ? bp.success : bp.textPrimary);
    final iconMuted = onLightTaskPanel && bp.brightness == Brightness.dark
        ? mutedOnCard
        : bp.listIconMuted;
    final hair = onLightTaskPanel && bp.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.18)
        : bp.listHairline;
    final cardFill = onLightTaskPanel && bp.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.06)
        : bp.listCardFill;
    final cardBorder = onLightTaskPanel && bp.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.14)
        : bp.listCardBorder;
    final dueLineColor = task.isDone
        ? (onLightTaskPanel && bp.brightness == Brightness.dark
            ? mutedOnCard
            : bp.textSecondary.withValues(alpha: 0.75))
        : (onLightTaskPanel && bp.brightness == Brightness.dark
            ? const Color(0xFFB91C1C)
            : _timeRed);
    final dueText = state.formatDueLineCompact(task.dueAt);

    final isRoutine =
        task.categoryTag == 'ROUTINE' || task.id.startsWith('rt_');
    const routineAccent = Color(0xFF7DB6A6);
    const routineAccentDeep = Color(0xFF4F8E7C);
    final routineFill = Color.alphaBlend(
      routineAccent.withValues(alpha: onLightTaskPanel ? 0.14 : 0.22),
      cardFill,
    );
    final routineBorder = routineAccent.withValues(alpha: 0.72);
    const attentionPink = Color(0xFFFF8A80);
    const attentionOrange = Color(0xFFFFB74D);
    final attentionFill = Color.alphaBlend(
      Color.lerp(attentionPink, attentionOrange, 0.5)!
          .withValues(alpha: onLightTaskPanel ? 0.22 : 0.28),
      cardFill,
    );
    final attentionBorder =
        Color.lerp(attentionPink, attentionOrange, 0.45)!.withValues(alpha: 0.88);
    final effectiveFill = isRoutine
        ? routineFill
        : (attentionHighlight ? attentionFill : cardFill);
    final effectiveBorder = isRoutine
        ? routineBorder
        : (attentionHighlight ? attentionBorder : cardBorder);
    final effectiveBorderWidth = isRoutine ? 2.0 : (attentionHighlight ? 2.0 : 1.0);

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
                    task: task,
                    hostContext: context,
                    onBeforeAction: onQuickActionDone,
                    onBulkModeForSheets: onBulkModeForSheets,
                    sheetUniverseTaskIds: sheetUniverseTaskIds,
                    sheetAllLabelKey: sheetAllLabelKey,
                  ),
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(isRoutine ? 10 : 8, 10, 6, 10),
            decoration: BoxDecoration(
              color: effectiveFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: effectiveBorder, width: effectiveBorderWidth),
              boxShadow: isRoutine
                  ? [
                      BoxShadow(
                        color: routineAccent.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isRoutine)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 6),
                    child: Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            routineAccent,
                            routineAccentDeep,
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isRoutine)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: task.isDone
                          ? routineAccent.withValues(alpha: 0.45)
                          : routineAccentDeep,
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCheckTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Container(
                        width: 38,
                        height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: bulkMode && selectedInBulk
                              ? accent
                              : (isRoutine
                                  ? routineAccent.withValues(
                                      alpha: task.isDone ? 0.35 : 0.85)
                                  : iconMuted),
                          width: 2,
                        ),
                        color: bulkMode
                            ? (selectedInBulk ? accent : Colors.transparent)
                            : (task.isDone ? bp.success : Colors.transparent),
                      ),
                        child: () {
                          final showCheck = bulkMode ? selectedInBulk : task.isDone;
                          return showCheck
                              ? Icon(Icons.check, color: bp.onPrimary, size: 20)
                              : null;
                        }(),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.only(right: 6),
                  color: hair,
                ),
                if (!isRoutine)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: task.categoryTag,
                      child: Icon(
                        state.iconForCategoryTag(task.categoryTag),
                        size: 18,
                        color: iconMuted.withValues(alpha: task.isDone ? 0.4 : 1),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 112,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      dueText,
                      maxLines: 1,
                      style: TextStyle(
                        color: dueLineColor,
                        fontWeight: FontWeight.w800,
                        fontSize: _adaptiveDueFontSize(
                          dueText,
                          onLightTaskPanel: onLightTaskPanel,
                        ),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (task.reminderOffsets != null && task.reminderOffsets!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: hi.withValues(alpha: task.isDone ? 0.4 : 1),
                    ),
                  ),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      color: titleFg,
                      fontWeight: FontWeight.w700,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                      decorationThickness: task.isDone ? 2.4 : null,
                      fontSize: _adaptiveTitleFontSize(task.title),
                      height: 1.1,
                    ),
                  ),
                ),
                if (task.recurrenceDays != null &&
                    task.recurrenceDays!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 72),
                      child: Text(
                        task.recurrenceDays!.join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent.withValues(
                              alpha: task.isDone ? 0.45 : 0.95),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onMenuTap,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: menuOpen
                              ? hi.withValues(alpha: 0.35)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: menuOpen ? bp.onPrimary : iconMuted,
                          size: 20,
                        ),
                      ),
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
}
