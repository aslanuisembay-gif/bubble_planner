import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../planner_languages.dart';
import '../translations.dart';
import 'font_card.dart';
import 'routine_card.dart';
import 'routine_editor_sheet.dart';
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
                    SettingsTab.feedback => const _FeedbackTab(),
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
          _segmentItem(tr('settingsTabFeedback', lang: languageCode), SettingsTab.feedback),
        ],
      ),
    );
  }

  Widget _segmentItem(String label, SettingsTab tab) {
    final isActive = tab == activeTab;
    return Expanded(
      child: Builder(
        builder: (context) {
          final seg = BubblePlannerColors.of(context).segmentActive;
          return GestureDetector(
            onTap: () => onChanged(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
              decoration: BoxDecoration(
                color: isActive ? seg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: seg.withValues(alpha: 0.45),
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
          );
        },
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
        const _AccountProfileCard(),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            tr('personaSectionTitle', lang: lang),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('personaGeneralTitle', lang: lang),
          subtitle: tr('personaGeneralSubtitle', lang: lang),
          previewIcons: const [
            Icons.grid_view_rounded,
            Icons.work_rounded,
            Icons.self_improvement_rounded,
          ],
          selected: state.bubblePlannerPersona == BubblePlannerPersona.general,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setBubblePlannerPersona(BubblePlannerPersona.general);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('personaStudentTitle', lang: lang),
          subtitle: tr('personaStudentSubtitle', lang: lang),
          previewIcons: const [
            Icons.school_rounded,
            Icons.menu_book_rounded,
            Icons.sports_basketball_rounded,
          ],
          selected: state.bubblePlannerPersona == BubblePlannerPersona.student,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setBubblePlannerPersona(BubblePlannerPersona.student);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('personaParentTitle', lang: lang),
          subtitle: tr('personaParentSubtitle', lang: lang),
          previewIcons: const [
            Icons.family_restroom_rounded,
            Icons.home_rounded,
            Icons.favorite_rounded,
          ],
          selected: state.bubblePlannerPersona == BubblePlannerPersona.parent,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setBubblePlannerPersona(BubblePlannerPersona.parent);
          },
        ),
        const SizedBox(height: 10),
        const _CategoryManagerCard(),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            tr('themeModeSectionTitle', lang: lang),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('themeModeSystem', lang: lang),
          subtitle: tr('themeModeSystemSubtitle', lang: lang),
          preview: const [Color(0xFF9CA3AF), Color(0xFF4B5563), Color(0xFFE5E7EB)],
          selected: state.themeMode == BubbleThemeMode.system,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setThemeMode(BubbleThemeMode.system);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('themeModeLight', lang: lang),
          subtitle: tr('themeModeLightSubtitle', lang: lang),
          preview: const [Color(0xFFFFFFFF), Color(0xFFE5E7EB), Color(0xFFCBD5E1)],
          selected: state.themeMode == BubbleThemeMode.light,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setThemeMode(BubbleThemeMode.light);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('themeModeDark', lang: lang),
          subtitle: tr('themeModeDarkSubtitle', lang: lang),
          preview: const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          selected: state.themeMode == BubbleThemeMode.dark,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setThemeMode(BubbleThemeMode.dark);
          },
        ),
        const SizedBox(height: 18),
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
              const SizedBox(height: 12),
              FontCard(
                title: 'Dancing Script',
                subtitle: tr('fontDancingSubtitle', lang: lang),
                titleStyle: GoogleFonts.dancingScript(fontSize: 26, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.dancingScript(fontSize: 16),
                selected: state.fontChoice == AppFontChoice.dancingScript,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.dancingScript),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Caveat',
                subtitle: tr('fontCaveatSubtitle', lang: lang),
                titleStyle: GoogleFonts.caveat(fontSize: 26, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.caveat(fontSize: 18),
                selected: state.fontChoice == AppFontChoice.caveat,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.caveat),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Kalam',
                subtitle: tr('fontKalamSubtitle', lang: lang),
                titleStyle: GoogleFonts.kalam(fontSize: 22, fontWeight: FontWeight.w400),
                subtitleStyle: GoogleFonts.kalam(fontSize: 16),
                selected: state.fontChoice == AppFontChoice.kalam,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.kalam),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Pacifico',
                subtitle: tr('fontPacificoSubtitle', lang: lang),
                titleStyle: GoogleFonts.pacifico(fontSize: 22),
                subtitleStyle: GoogleFonts.pacifico(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.pacifico,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.pacifico),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Rubik',
                subtitle: tr('fontRubikSubtitle', lang: lang),
                titleStyle: GoogleFonts.rubik(fontSize: 18, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.rubik(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.rubik,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.rubik),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Space Grotesk',
                subtitle: tr('fontSpaceGroteskSubtitle', lang: lang),
                titleStyle: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.spaceGrotesk(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.spaceGrotesk,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.spaceGrotesk),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Outfit',
                subtitle: tr('fontOutfitSubtitle', lang: lang),
                titleStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.outfit(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.outfit,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.outfit),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Nunito',
                subtitle: tr('fontNunitoSubtitle', lang: lang),
                titleStyle: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
                subtitleStyle: GoogleFonts.nunito(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.nunito,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.nunito),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Playfair Display',
                subtitle: tr('fontPlayfairSubtitle', lang: lang),
                titleStyle: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.playfairDisplay(fontSize: 15),
                selected: state.fontChoice == AppFontChoice.playfairDisplay,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.playfairDisplay),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Merriweather',
                subtitle: tr('fontMerriweatherSubtitle', lang: lang),
                titleStyle: GoogleFonts.merriweather(fontSize: 17, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.merriweather(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.merriweather,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.merriweather),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Inter',
                subtitle: tr('fontInterSubtitle', lang: lang),
                titleStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                subtitleStyle: GoogleFonts.inter(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.inter,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.inter),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Manrope',
                subtitle: tr('fontManropeSubtitle', lang: lang),
                titleStyle: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700),
                subtitleStyle: GoogleFonts.manrope(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.manrope,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.manrope),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Sora',
                subtitle: tr('fontSoraSubtitle', lang: lang),
                titleStyle: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700),
                subtitleStyle: GoogleFonts.sora(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.sora,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.sora),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'IBM Plex Sans',
                subtitle: tr('fontIbmPlexSansSubtitle', lang: lang),
                titleStyle: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.ibmPlexSans(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.ibmPlexSans,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.ibmPlexSans),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Fira Sans',
                subtitle: tr('fontFiraSansSubtitle', lang: lang),
                titleStyle: GoogleFonts.firaSans(fontSize: 18, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.firaSans(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.firaSans,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.firaSans),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Josefin Sans',
                subtitle: tr('fontJosefinSubtitle', lang: lang),
                titleStyle: GoogleFonts.josefinSans(fontSize: 20, fontWeight: FontWeight.w600),
                subtitleStyle: GoogleFonts.josefinSans(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.josefinSans,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.josefinSans),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Bebas Neue',
                subtitle: tr('fontBebasSubtitle', lang: lang),
                titleStyle: GoogleFonts.bebasNeue(fontSize: 26),
                subtitleStyle: GoogleFonts.bebasNeue(fontSize: 18),
                selected: state.fontChoice == AppFontChoice.bebasNeue,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.bebasNeue),
              ),
              const SizedBox(height: 12),
              FontCard(
                title: 'Libre Baskerville',
                subtitle: tr('fontLibreBaskervilleSubtitle', lang: lang),
                titleStyle: GoogleFonts.libreBaskerville(fontSize: 18, fontWeight: FontWeight.w700),
                subtitleStyle: GoogleFonts.libreBaskerville(fontSize: 14),
                selected: state.fontChoice == AppFontChoice.libreBaskerville,
                onTap: () => context.read<AppState>().setFontChoice(AppFontChoice.libreBaskerville),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            tr('colorPaletteSectionTitle', lang: lang),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('paletteClassicName', lang: lang),
          subtitle: tr('paletteClassicSubtitle', lang: lang),
          preview: const [Color(0xFF0B1018), Color(0xFF58A6FF), Color(0xFF8B5CF6)],
          selected: state.colorPaletteId == AppColorPaletteId.classic,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.classic);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('paletteWellnessName', lang: lang),
          subtitle: tr('paletteWellnessSubtitle', lang: lang),
          preview: const [Color(0xFFE8F5F0), Color(0xFF2EB88A), Color(0xFF5ECFB0)],
          selected: state.colorPaletteId == AppColorPaletteId.wellnessMint,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.wellnessMint);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('paletteLavenderName', lang: lang),
          subtitle: tr('paletteLavenderSubtitle', lang: lang),
          preview: const [Color(0xFFF3EEF9), Color(0xFF8B5CF6), Color(0xFFC4B5FD)],
          selected: state.colorPaletteId == AppColorPaletteId.softLavender,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.softLavender);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('paletteOceanName', lang: lang),
          subtitle: tr('paletteOceanSubtitle', lang: lang),
          preview: const [Color(0xFFE8F4FC), Color(0xFF0EA5E9), Color(0xFF38BDF8)],
          selected: state.colorPaletteId == AppColorPaletteId.oceanBreeze,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.oceanBreeze);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('paletteSunsetName', lang: lang),
          subtitle: tr('paletteSunsetSubtitle', lang: lang),
          preview: const [Color(0xFFFFEFEA), Color(0xFFEF6B5A), Color(0xFFF59E7B)],
          selected: state.colorPaletteId == AppColorPaletteId.sunsetCoral,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.sunsetCoral);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('paletteNeonName', lang: lang),
          subtitle: tr('paletteNeonSubtitle', lang: lang),
          preview: const [Color(0xFF050D1C), Color(0xFF00E5FF), Color(0xFF8B5CF6)],
          selected: state.colorPaletteId == AppColorPaletteId.midnightNeon,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.midnightNeon);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('paletteForestName', lang: lang),
          subtitle: tr('paletteForestSubtitle', lang: lang),
          preview: const [Color(0xFFE8F1E4), Color(0xFF3F7D3B), Color(0xFF6A9C5E)],
          selected: state.colorPaletteId == AppColorPaletteId.forestMoss,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.forestMoss);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('paletteMonoName', lang: lang),
          subtitle: tr('paletteMonoSubtitle', lang: lang),
          preview: const [Color(0xFF0C0C0C), Color(0xFFE5E5E5), Color(0xFFA3A3A3)],
          selected: state.colorPaletteId == AppColorPaletteId.monochromeInk,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.monochromeInk);
          },
        ),
        const SizedBox(height: 10),
        _PalettePreviewCard(
          title: tr('palettePeachName', lang: lang),
          subtitle: tr('palettePeachSubtitle', lang: lang),
          preview: const [Color(0xFFFFF6EE), Color(0xFFFF8A5B), Color(0xFFFFB088)],
          selected: state.colorPaletteId == AppColorPaletteId.peachSorbet,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<AppState>().setColorPaletteId(AppColorPaletteId.peachSorbet);
          },
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
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await context.read<AppState>().logout();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
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

class _AccountProfileCard extends StatefulWidget {
  const _AccountProfileCard();

  @override
  State<_AccountProfileCard> createState() => _AccountProfileCardState();
}

class _AccountProfileCardState extends State<_AccountProfileCard> {
  late final TextEditingController _nameController;
  String? _draftAvatarBase64;
  bool _clearAvatar = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().userProfile;
    _nameController = TextEditingController(text: profile.displayName);
    _draftAvatarBase64 = profile.avatarBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _draftAvatarBase64 = base64Encode(bytes);
      _clearAvatar = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppState>().saveUserProfile(
          displayName: _nameController.text,
          avatarBase64: _draftAvatarBase64,
          clearAvatar: _clearAvatar,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('accountSaved', lang: context.read<AppState>().languageCode))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.languageCode;
    final avatar = !_clearAvatar ? (_draftAvatarBase64 ?? state.avatarBase64) : null;
    final avatarBytes = avatar == null ? null : base64Decode(avatar);

    return _LightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('accountSectionTitle', lang: lang),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF161719),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFFE8EEF6),
                backgroundImage: avatarBytes == null ? null : MemoryImage(avatarBytes),
                child: avatarBytes == null
                    ? const Icon(Icons.person_rounded, size: 34, color: Color(0xFF5D6B7A))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Color(0xFF161719)),
                      decoration: InputDecoration(
                        labelText: tr('accountNameLabel', lang: lang),
                        hintText: tr('accountNameHint', lang: lang),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _pickAvatar,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(tr('accountPhotoButton', lang: lang)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (avatar != null)
                          IconButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _draftAvatarBase64 = null;
                                      _clearAvatar = true;
                                    }),
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: const Color(0xFFBB2A2A),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(tr('accountSaveButton', lang: lang)),
          ),
        ],
      ),
    );
  }
}

class _RoutinesTab extends StatelessWidget {
  const _RoutinesTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final routines = state.routines;
    final lang = state.languageCode;
    return Column(
      key: const ValueKey('routines'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            showRoutineEditorSheet(context);
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('routineAdd', lang: lang)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final item = routines[index];
              return RoutineCard(
                item: item,
                onEdit: () {
                  HapticFeedback.selectionClick();
                  showRoutineEditorSheet(context, initial: item);
                },
                onDelete: () {
                  HapticFeedback.lightImpact();
                  context.read<AppState>().removeRoutine(item.id);
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
          ),
        ),
      ],
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
        for (final code in kPlannerLanguageCodes)
          tile(code, plannerLanguageNativeLabel(code)),
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

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();
  bool _preferPhone = false;

  static final Uri _supportEmail = Uri(
    scheme: 'mailto',
    path: 'aslan01@bu.edu',
  );
  static final Uri _supportPhone = Uri(
    scheme: 'tel',
    path: '+77000000000',
  );

  @override
  void dispose() {
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  bool _validContact(String value, {required bool phone}) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (phone) {
      return RegExp(r'^[0-9+\-\s()]{7,}$').hasMatch(v);
    }
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
  }

  Future<void> _sendFeedback(BuildContext context, String lang) async {
    final state = context.read<AppState>();
    final contact = _contactController.text.trim();
    final message = _messageController.text.trim();
    if (!_validContact(contact, phone: _preferPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('feedbackValidationContact', lang: lang))),
      );
      return;
    }
    if (message.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('feedbackValidationMessage', lang: lang))),
      );
      return;
    }
    final ok = await state.submitFeedback(
      contact: contact,
      preferPhone: _preferPhone,
      message: message,
    );
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('feedbackSent', lang: lang))),
      );
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('feedbackSendFailed', lang: lang))),
      );
    }
  }

  Future<void> _quickLaunch(BuildContext context, Uri uri, String lang) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('feedbackOpenFailed', lang: lang))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    return ListView(
      key: const ValueKey('feedback'),
      padding: EdgeInsets.zero,
      children: [
        Text(
          tr('feedbackTitle', lang: lang),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          tr('feedbackSubtitle', lang: lang),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
        ),
        const SizedBox(height: 16),
        Text(
          tr('feedbackPreferredContact', lang: lang),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(tr('feedbackViaEmail', lang: lang)),
                selected: !_preferPhone,
                onSelected: (_) => setState(() => _preferPhone = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text(tr('feedbackViaPhone', lang: lang)),
                selected: _preferPhone,
                onSelected: (_) => setState(() => _preferPhone = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _contactController,
          keyboardType: _preferPhone ? TextInputType.phone : TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _preferPhone
                ? tr('feedbackContactHintPhone', lang: lang)
                : tr('feedbackContactHintEmail', lang: lang),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageController,
          minLines: 4,
          maxLines: 6,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: tr('feedbackMessageLabel', lang: lang),
            hintText: tr('feedbackMessageHint', lang: lang),
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _sendFeedback(context, lang),
          icon: const Icon(Icons.send_rounded),
          label: Text(tr('feedbackSend', lang: lang)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _quickLaunch(context, _supportEmail, lang),
          icon: const Icon(Icons.alternate_email_rounded),
          label: Text(tr('feedbackQuickEmail', lang: lang)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _quickLaunch(context, _supportPhone, lang),
          icon: const Icon(Icons.phone_rounded),
          label: Text(tr('feedbackQuickPhone', lang: lang)),
        ),
      ],
    );
  }
}

class _CategoryManagerCard extends StatelessWidget {
  const _CategoryManagerCard();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    return _LightCard(
      child: Row(
        children: [
          const Icon(Icons.category_outlined, color: Color(0xFF4B5563)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('categoryManagerTitle', lang: lang),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF161719),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('categoryManagerSubtitle', lang: lang),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF454A53)),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _CategoryManagerSheet(),
              );
            },
            child: Text(tr('categoryManagerOpen', lang: lang)),
          ),
        ],
      ),
    );
  }
}

class _CategoryManagerSheet extends StatefulWidget {
  const _CategoryManagerSheet();

  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  BubblePlannerPersona _persona = BubblePlannerPersona.general;

  Future<void> _askAdd(AppState state, String lang) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('categoryManagerAdd', lang: lang)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: tr('categoryManagerNameHint', lang: lang)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel', lang: lang))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save', lang: lang))),
        ],
      ),
    );
    if (ok != true) return;
    await state.addCategoryForPersona(_persona, ctrl.text);
    ctrl.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _askRename(AppState state, String categoryId, String currentTitle, String lang) async {
    final ctrl = TextEditingController(text: currentTitle);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('categoryManagerRename', lang: lang)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: tr('categoryManagerNameHint', lang: lang)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel', lang: lang))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save', lang: lang))),
        ],
      ),
    );
    if (ok != true) return;
    await state.renameCategoryForPersona(_persona, categoryId, ctrl.text);
    ctrl.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.languageCode;
    final items = state.categoryManagerList(_persona);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151018),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  tr('categoryManagerTitle', lang: lang),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _personaChip(lang, tr('personaGeneralTitle', lang: lang), BubblePlannerPersona.general)),
                const SizedBox(width: 8),
                Expanded(child: _personaChip(lang, tr('personaStudentTitle', lang: lang), BubblePlannerPersona.student)),
                const SizedBox(width: 8),
                Expanded(child: _personaChip(lang, tr('personaParentTitle', lang: lang), BubblePlannerPersona.parent)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final c = items[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: c.color, radius: 10),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _askRename(state, c.id, c.title, lang),
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                          tooltip: tr('categoryManagerRename', lang: lang),
                        ),
                        IconButton(
                          onPressed: () async {
                            await state.deleteCategoryForPersona(_persona, c.id);
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF8A80)),
                          tooltip: tr('categoryManagerDelete', lang: lang),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _askAdd(state, lang),
                icon: const Icon(Icons.add_rounded),
                label: Text(tr('categoryManagerAdd', lang: lang)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personaChip(String lang, String label, BubblePlannerPersona p) {
    final on = _persona == p;
    return InkWell(
      onTap: () => setState(() => _persona = p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? const Color(0xFFBFA6FF) : Colors.white24),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: on ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PalettePreviewCard extends StatelessWidget {
  const _PalettePreviewCard({
    required this.title,
    required this.subtitle,
    this.preview = const [],
    this.previewIcons = const [],
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> preview;
  final List<IconData> previewIcons;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? const Color(0xFF78A6FF) : const Color(0xFFDCE1E8),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              if (previewIcons.isNotEmpty)
                for (var i = 0; i < previewIcons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDCE1E8), width: 1.5),
                    ),
                    child: Icon(
                      previewIcons[i],
                      size: 16,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ]
              else
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: preview[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF161719),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF454A53)),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF78A6FF), size: 24),
            ],
          ),
        ),
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
