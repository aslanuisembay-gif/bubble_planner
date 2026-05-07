import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../translations.dart';

Future<void> showRoutineEditorSheet(
  BuildContext context, {
  RoutineItem? initial,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (ctx) => _RoutineEditorBody(initial: initial),
  );
}

class _RoutineEditorBody extends StatefulWidget {
  const _RoutineEditorBody({this.initial});

  final RoutineItem? initial;

  @override
  State<_RoutineEditorBody> createState() => _RoutineEditorBodyState();
}

class _RoutineEditorBodyState extends State<_RoutineEditorBody> {
  late final TextEditingController _title;
  late final TextEditingController _timeRange;
  late String _iconKey;
  late TimeOfDay _start;

  static const _iconKeys = ['sun', 'work', 'moon', 'fitness', 'book', 'coffee'];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _title = TextEditingController(text: i?.title ?? '');
    _timeRange = TextEditingController(text: i?.timeRange ?? '');
    _iconKey = i?.iconKey ?? 'sun';
    _start = TimeOfDay(hour: i?.startHour ?? 7, minute: i?.startMinute ?? 0);
  }

  @override
  void dispose() {
    _title.dispose();
    _timeRange.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    final bp = context.bp;
    final bottom = MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: bp.modalSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: bp.modalBorder),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null
                    ? tr('routineAdd', lang: lang)
                    : tr('routineEdit', lang: lang),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: bp.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                style: TextStyle(color: bp.textPrimary),
                decoration: InputDecoration(
                  labelText: tr('routineName', lang: lang),
                  labelStyle: TextStyle(color: bp.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _timeRange,
                style: TextStyle(color: bp.textPrimary),
                decoration: InputDecoration(
                  labelText: tr('due', lang: lang),
                  hintText: '07:00 - 09:00',
                  labelStyle: TextStyle(color: bp.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('routineTimeHint', lang: lang),
                style: TextStyle(color: bp.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _start,
                    );
                    if (t != null) setState(() => _start = t);
                  },
                  icon: const Icon(Icons.schedule_rounded, size: 20),
                  label: Text(
                    '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in _iconKeys)
                    ChoiceChip(
                      label: Icon(routineIconFromKey(k), size: 22),
                      selected: _iconKey == k,
                      onSelected: (_) => setState(() => _iconKey = k),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('cancel', lang: lang)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final title = _title.text.trim();
                      if (title.isEmpty) return;
                      final state = context.read<AppState>();
                      final id = widget.initial?.id ?? 'r_${DateTime.now().millisecondsSinceEpoch}';
                      final trange = _timeRange.text.trim().isEmpty
                          ? '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}'
                          : _timeRange.text.trim();
                      state.upsertRoutine(
                        RoutineItem(
                          id: id,
                          iconKey: _iconKey,
                          title: title,
                          timeRange: trange,
                          startHour: _start.hour,
                          startMinute: _start.minute,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: Text(tr('routineSave', lang: lang)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
