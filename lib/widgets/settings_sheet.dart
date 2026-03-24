import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
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
  const _SegmentedTabs({required this.activeTab, required this.onChanged});

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
          _segmentItem('Appearance', SettingsTab.appearance),
          _segmentItem('Routines', SettingsTab.routines),
          _segmentItem('Language', SettingsTab.language),
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
          padding: const EdgeInsets.symmetric(vertical: 11),
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(isActive ? 1 : 0.72),
              fontWeight: FontWeight.w600,
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
    return ListView(
      key: const ValueKey('appearance'),
      children: [
        _LightCard(
          child: Column(
            children: [
              FontCard(
                title: 'Default font',
                subtitle: 'The quick brown fox jumps over the lazy dog (Abc)',
                titleStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                subtitleStyle: const TextStyle(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.systemDefault,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.systemDefault),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Press Start 2P',
                subtitle: 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG',
                titleStyle: GoogleFonts.pressStart2p(fontSize: 12),
                subtitleStyle: GoogleFonts.pressStart2p(fontSize: 8),
                selected: state.fontChoice == AppFontChoice.pressStart2p,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.pressStart2p),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Special Elite',
                subtitle: 'The quick brown fox jumps over the lazy dog',
                titleStyle: GoogleFonts.specialElite(fontSize: 20),
                subtitleStyle: GoogleFonts.specialElite(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.specialElite,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.specialElite),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Cinzel',
                subtitle: 'Elegant serif preview for premium look',
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
          title: 'Enable Daily Routines',
          value: state.dailyRoutinesEnabled,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            context.read<AppState>().toggleDailyRoutines(v);
          },
        ),
        const SizedBox(height: 10),
        ToggleTile(
          icon: Icons.graphic_eq_rounded,
          title: 'Voice Activation ("Bubble")',
          subtitle:
              'Experimental: app stays active to listen for the "bubble" wake word.',
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
          label: const Text('Logout', style: TextStyle(color: Color(0xFFBB2A2A))),
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
    return Container(
      key: const ValueKey('language'),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Language', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'English and Russian are available. Hook your localization state here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.74),
                ),
          ),
        ],
      ),
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
