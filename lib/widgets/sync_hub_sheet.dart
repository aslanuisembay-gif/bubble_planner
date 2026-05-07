import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../translations.dart';

class SyncHubSheet extends StatefulWidget {
  const SyncHubSheet({super.key});

  @override
  State<SyncHubSheet> createState() => _SyncHubSheetState();
}

class _SyncHubSheetState extends State<SyncHubSheet> {
  int _step = 0;
  final List<String> _previewTasks = const [
    'REVIEW EMAIL FROM TEAM',
    'ORDER SUPPLIES FROM LIST',
    'FOLLOW UP CALENDAR INVITE',
    'SCHEDULE CHECKUP FROM NOTE',
  ];
  late final Set<String> _selectedPreviewTasks = {..._previewTasks};

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    final bp = context.bp;
    final accent = bp.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: bp.modalSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: bp.modalBorder),
      ),
      child: _step == 0
          ? _buildIntro(context, lang, bp, accent)
          : _step == 1
              ? _buildServices(context, lang, bp, accent)
              : _buildReview(context, lang, bp, accent),
    );
  }

  Widget _buildIntro(
    BuildContext context,
    String lang,
    BubblePlannerColors bp,
    Color accent,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.sync_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              tr('syncHubTitle', lang: lang),
              style: TextStyle(
                color: bp.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: bp.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bp.listCardFill.withValues(alpha: 0.45),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: accent, size: 48),
        ),
        const SizedBox(height: 20),
        Text(
          tr('syncHubIntro', lang: lang),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: bp.textPrimary.withValues(alpha: 0.88),
            height: 1.45,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => setState(() => _step = 1),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: bp.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(tr('syncContinue', lang: lang), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildServices(
    BuildContext context,
    String lang,
    BubblePlannerColors bp,
    Color accent,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.sync_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              tr('syncHubTitle', lang: lang),
              style: TextStyle(
                color: bp.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: bp.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _serviceCard(
          icon: Icons.mail_outline_rounded,
          iconBg: const Color(0xFFE94235),
          title: tr('syncGmailTitle', lang: lang),
          subtitle: tr('syncGmailSubtitle', lang: lang),
          badge: '+2',
          bp: bp,
        ),
        const SizedBox(height: 10),
        _serviceCard(
          icon: Icons.calendar_today_rounded,
          iconBg: const Color(0xFF4285F4),
          title: tr('syncCalTitle', lang: lang),
          subtitle: tr('syncCalSubtitle', lang: lang),
          badge: '+1',
          bp: bp,
        ),
        const SizedBox(height: 10),
        _serviceCard(
          icon: Icons.note_alt_outlined,
          iconBg: const Color(0xFFFFCC33),
          title: tr('syncNotesTitle', lang: lang),
          subtitle: tr('syncNotesSubtitle', lang: lang),
          badge: '+1',
          bp: bp,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bp.success.withValues(alpha: bp.brightness == Brightness.dark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bp.success.withValues(alpha: 0.85), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: bp.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr('syncFoundTasks', lang: lang),
                    style: TextStyle(
                      color: bp.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr('syncFoundSubtitle', lang: lang),
                style: TextStyle(
                  color: bp.textPrimary.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => setState(() => _step = 2),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: bp.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              tr('syncReviewTasks', lang: lang),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReview(
    BuildContext context,
    String lang,
    BubblePlannerColors bp,
    Color accent,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _step = 1),
              icon: Icon(Icons.arrow_back_rounded, color: bp.textSecondary),
              tooltip: tr('syncBack', lang: lang),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                tr('syncReviewTitle', lang: lang),
                style: TextStyle(
                  color: bp.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: bp.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _previewTasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final taskTitle = _previewTasks[i];
              final selected = _selectedPreviewTasks.contains(taskTitle);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bp.listCardFill.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bp.listCardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.task_alt_rounded, color: bp.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        taskTitle,
                        style: TextStyle(
                          color: bp.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Checkbox.adaptive(
                      value: selected,
                      activeColor: accent,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedPreviewTasks.add(taskTitle);
                          } else {
                            _selectedPreviewTasks.remove(taskTitle);
                          }
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _selectedPreviewTasks.isEmpty
                ? null
                : () {
                    context
                        .read<AppState>()
                        .applySyncHubResultsSelected(_selectedPreviewTasks);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('syncTasksAddedSnack', lang: lang))),
              );
                  },
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: bp.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              tr('syncAddToPlanner', lang: lang),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _serviceCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badge,
    required BubblePlannerColors bp,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bp.listCardFill.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bp.listCardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: bp.textPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: bp.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(Icons.check_circle_rounded, color: bp.success, size: 22),
              Text(
                badge,
                style: TextStyle(
                  color: bp.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
