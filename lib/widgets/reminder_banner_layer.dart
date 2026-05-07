import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../translations.dart';

/// Верхний баннер напоминаний (похож на iOS banner): задачи с [reminderOffsets], окно после наступления времени.
class ReminderBannerLayer extends StatefulWidget {
  const ReminderBannerLayer({super.key});

  @override
  State<ReminderBannerLayer> createState() => _ReminderBannerLayerState();
}

class _ReminderBannerLayerState extends State<ReminderBannerLayer> {
  Timer? _timer;
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bp = context.bp;
    final lang = state.languageCode;
    final now = DateTime.now();

    BubbleTaskItem? bestTask;
    int? bestOffset;
    DateTime? bestFire;

    for (final task in state.tasks) {
      if (task.isDone) continue;
      final ro = task.reminderOffsets;
      if (ro == null || ro.isEmpty) continue;
      for (final off in ro) {
        final fireAt = task.dueAt.subtract(Duration(minutes: off));
        final key = '${task.id}_${off}_${fireAt.millisecondsSinceEpoch ~/ 60000}';
        if (_dismissed.contains(key)) continue;
        if (now.isBefore(fireAt)) continue;
        if (now.difference(fireAt) > const Duration(minutes: 15)) continue;
        if (bestFire == null || fireAt.isAfter(bestFire)) {
          bestFire = fireAt;
          bestTask = task;
          bestOffset = off;
        }
      }
    }

    if (bestTask == null || bestOffset == null || bestFire == null) {
      return const SizedBox.shrink();
    }

    final dismissKey =
        '${bestTask.id}_${bestOffset}_${bestFire.millisecondsSinceEpoch ~/ 60000}';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Material(
          elevation: 12,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          color: bp.modalSurface,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bp.modalBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 3, color: bp.talkAccent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: bp.talkAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr('reminderBannerBody', lang: lang),
                                style: TextStyle(
                                  color: bp.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bestTask.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: bp.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _dismissed.add(dismissKey)),
                          icon: Icon(Icons.close_rounded, color: bp.textSecondary, size: 22),
                          tooltip: tr('reminderBannerDismiss', lang: lang),
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
    );
  }
}
