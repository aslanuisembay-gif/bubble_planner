import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../translations.dart';

class SyncHubSheet extends StatefulWidget {
  const SyncHubSheet({super.key});

  @override
  State<SyncHubSheet> createState() => _SyncHubSheetState();
}

class _SyncHubSheetState extends State<SyncHubSheet> {
  int _step = 0;

  static const _purple = Color(0xFF9D00FF);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF151018),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: _step == 0 ? _buildIntro(context, lang) : _buildServices(context, lang),
    );
  }

  Widget _buildIntro(BuildContext context, String lang) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sync_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              tr('syncHubTitle', lang: lang),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: _purple, size: 48),
        ),
        const SizedBox(height: 20),
        Text(
          tr('syncHubIntro', lang: lang),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
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
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(tr('syncContinue', lang: lang), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildServices(BuildContext context, String lang) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sync_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              tr('syncHubTitle', lang: lang),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
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
        ),
        const SizedBox(height: 10),
        _serviceCard(
          icon: Icons.calendar_today_rounded,
          iconBg: const Color(0xFF4285F4),
          title: tr('syncCalTitle', lang: lang),
          subtitle: tr('syncCalSubtitle', lang: lang),
          badge: '+1',
        ),
        const SizedBox(height: 10),
        _serviceCard(
          icon: Icons.note_alt_outlined,
          iconBg: const Color(0xFFFFCC33),
          title: tr('syncNotesTitle', lang: lang),
          subtitle: tr('syncNotesSubtitle', lang: lang),
          badge: '+1',
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2A18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF34D399), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF34D399), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr('syncFoundTasks', lang: lang),
                    style: TextStyle(
                      color: const Color(0xFF6EE7B7),
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
                  color: Colors.white.withValues(alpha: 0.72),
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
            onPressed: () {
              context.read<AppState>().applySyncHubResults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('syncTasksAddedSnack', lang: lang))),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(tr('syncAddToPlanner', lang: lang), style: const TextStyle(fontWeight: FontWeight.w700)),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 22),
              Text(badge, style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
