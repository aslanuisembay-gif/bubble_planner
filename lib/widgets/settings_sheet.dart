import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../translations.dart';
import 'font_card.dart';
import 'routine_card.dart';
import 'toggle_tile.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF11141D).withOpacity(0.82),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.36),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              _SegmentedTabs(
                languageCode: state.languageCode,
                activeTab: state.activeSettingsTab,
                onChanged: (tab) {
                  HapticFeedback.selectionClick();
                  context.read<AppState>().setActiveSettingsTab(tab);
                },
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOut,
                  child: switch (state.activeSettingsTab) {
                    SettingsTab.appearance => const _AppearanceTab(),
                    SettingsTab.routines => const _RoutinesTab(),
                    SettingsTab.language => const _LanguageTab(),
                    SettingsTab.legal => const _LegalTab(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.languageCode,
    required this.activeTab,
    required this.onChanged,
  });

  final String languageCode;
  final SettingsTab activeTab;
  final ValueChanged<SettingsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _segmentItem(tr('settingsTabAppearance', lang: languageCode), SettingsTab.appearance),
          _segmentItem(tr('settingsTabRoutines', lang: languageCode), SettingsTab.routines),
          _segmentItem(tr('settingsTabLanguage', lang: languageCode), SettingsTab.language),
          _segmentItem(tr('settingsTabLegal', lang: languageCode), SettingsTab.legal),
        ],
      ),
    );
  }

  Widget _segmentItem(String label, SettingsTab tab) {
    final isActive = tab == activeTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF4F89FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F89FF).withOpacity(0.5),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(isActive ? 1 : 0.72),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.languageCode;
    return ListView(
      key: const ValueKey('appearance'),
      children: [
        _LightCard(
          child: Column(
            children: [
              FontCard(
                title: tr('fontDefaultTitle', lang: lang),
                subtitle: tr('fontDefaultSubtitle', lang: lang),
                titleStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                subtitleStyle: const TextStyle(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.systemDefault,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.systemDefault),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Press Start 2P',
                subtitle: tr('fontPressStartSubtitle', lang: lang),
                titleStyle: GoogleFonts.pressStart2p(fontSize: 12),
                subtitleStyle: GoogleFonts.pressStart2p(fontSize: 8),
                selected: state.fontChoice == AppFontChoice.pressStart2p,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.pressStart2p),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Special Elite',
                subtitle: tr('fontSpecialEliteSubtitle', lang: lang),
                titleStyle: GoogleFonts.specialElite(fontSize: 20),
                subtitleStyle: GoogleFonts.specialElite(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.specialElite,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.specialElite),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Cinzel',
                subtitle: tr('fontCinzelSubtitle', lang: lang),
                titleStyle: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.cinzel(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.cinzel,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.cinzel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ToggleTile(
          icon: Icons.wb_sunny_outlined,
          title: tr('enableDailyRoutines', lang: lang),
          value: state.dailyRoutinesEnabled,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            context.read<AppState>().toggleDailyRoutines(v);
          },
        ),
        const SizedBox(height: 10),
        ToggleTile(
          icon: Icons.graphic_eq_rounded,
          title: tr('voiceActivationTitle', lang: lang),
          subtitle: tr('voiceActivationSubtitle', lang: lang),
          value: state.voiceActivationEnabled,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            context.read<AppState>().toggleVoiceActivation(v);
          },
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => HapticFeedback.mediumImpact(),
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFBB2A2A)),
          label: Text(tr('logout', lang: lang), style: const TextStyle(color: Color(0xFFBB2A2A))),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFD8D8),
            foregroundColor: const Color(0xFFBB2A2A),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    );
  }
}

class _RoutinesTab extends StatelessWidget {
  const _RoutinesTab();

  @override
  Widget build(BuildContext context) {
    final routines = context.watch<AppState>().routines;
    return ListView.separated(
      key: const ValueKey('routines'),
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final item = routines[index];
        return RoutineCard(
          item: item,
          onDelete: () {
            HapticFeedback.lightImpact();
            context.read<AppState>().removeRoutine(item.id);
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
    );
  }
}

class _LanguageTab extends StatelessWidget {
  const _LanguageTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.languageCode;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withOpacity(0.74),
        );

    Widget tile(String code, String label) {
      final selected = state.languageCode == code;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected ? const Color(0xFF4F89FF).withOpacity(0.35) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<AppState>().setLanguageCode(code);
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? const Color(0xFF93C5FD) : Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('language'),
      padding: EdgeInsets.zero,
      children: [
        Text(tr('languageScreenTitle', lang: lang), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Text(tr('languageScreenSubtitle', lang: lang), style: bodyStyle),
        const SizedBox(height: 18),
        tile('en', tr('languageEnglish', lang: lang)),
        tile('ru', tr('languageRussian', lang: lang)),
      ],
    );
  }
}

class _LegalTab extends StatelessWidget {
  const _LegalTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.languageCode;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withOpacity(0.88),
          height: 1.45,
        );
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        );

    return ListView(
      key: ValueKey('legal_$lang'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(tr('legalScreenTitle', lang: lang), style: titleStyle),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('legalPrivacyTitle', lang: lang), style: titleStyle),
              const SizedBox(height: 10),
              Text(tr('legalPrivacyBody', lang: lang).trim(), style: bodyStyle),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('legalConsentTitle', lang: lang), style: titleStyle),
              const SizedBox(height: 10),
              Text(tr('legalConsentBody', lang: lang).trim(), style: bodyStyle),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.legalConsentAccepted)
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF65DEA3), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('legalConsentSavedLine', lang: lang),
                  style: bodyStyle?.copyWith(color: const Color(0xFF65DEA3)),
                ),
              ),
            ],
          )
        else
          FilledButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await context.read<AppState>().acceptLegalConsent();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('legalConsentSnackbar', lang: lang)),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F89FF),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Text(tr('legalAcceptButton', lang: lang)),
          ),
        const SizedBox(height: 12),
        Text(
          tr('legalNotice', lang: lang),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.45),
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
