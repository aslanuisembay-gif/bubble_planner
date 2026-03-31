import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class ConfirmTaskSheet extends StatefulWidget {
  const ConfirmTaskSheet({super.key, required this.initialTitle});

  final String initialTitle;

  @override
  State<ConfirmTaskSheet> createState() => _ConfirmTaskSheetState();
}

class _ConfirmTaskSheetState extends State<ConfirmTaskSheet> {
  late final TextEditingController _title;
  late DateTime _day;
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  static const _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    _hour = n.hour;
    _minute = (n.minute ~/ 5) * 5;
    _dayController = FixedExtentScrollController();
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute ~/ 5);
  }

  @override
  void dispose() {
    _title.dispose();
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: BoxDecoration(
          color: const Color(0xFF141018),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm Task',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'TASK',
              style: TextStyle(
                color: _purple.withValues(alpha: 0.9),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.35),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('КОГДА', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 12)),
                const Spacer(),
                Text('HOUR', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(width: 48),
                Text('MIN', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _wheel(
                    height: 120,
                    child: ListWheelScrollView.useDelegate(
                      controller: _dayController,
                      itemExtent: 36,
                      diameterRatio: 1.4,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) {
                        setState(() {
                          if (i == 0) {
                            final n = DateTime.now();
                            _day = DateTime(n.year, n.month, n.day);
                          } else {
                            final n = DateTime.now();
                            final t = n.add(const Duration(days: 1));
                            _day = DateTime(t.year, t.month, t.day);
                          }
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 2,
                        builder: (_, i) => Center(
                          child: Text(
                            i == 0 ? 'Today' : 'Tomorrow',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _wheel(
                    height: 120,
                    child: ListWheelScrollView.useDelegate(
                      controller: _hourController,
                      itemExtent: 36,
                      diameterRatio: 1.4,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) => setState(() => _hour = i),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 24,
                        builder: (_, i) => Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _wheel(
                    height: 120,
                    child: ListWheelScrollView.useDelegate(
                      controller: _minuteController,
                      itemExtent: 36,
                      diameterRatio: 1.4,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) => setState(() => _minute = i * 5),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 12,
                        builder: (_, i) => Center(
                          child: Text(
                            (i * 5).toString().padLeft(2, '0'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      final text = _title.text.trim();
                      if (text.isEmpty) return;
                      final due = DateTime(_day.year, _day.month, _day.day, _hour, _minute);
                      context.read<AppState>().addConfirmedTask(text, due);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('OK, Add Task', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({required double height, required Widget child}) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
