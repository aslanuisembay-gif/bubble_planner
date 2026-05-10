import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../services/paper_scan.dart';
import '../services/voice_input_errors.dart';
import 'confirm_task_sheet.dart';
import '../translations.dart';

/// Полноэкранное добавление задачи: анимация «пишущего карандаша» и подсказка.
Future<void> showStickyNoteAddTaskSheet(BuildContext context) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: const _FullScreenAddTaskPage(),
        );
      },
    ),
  );
}

class _FullScreenAddTaskPage extends StatefulWidget {
  const _FullScreenAddTaskPage();

  @override
  State<_FullScreenAddTaskPage> createState() => _FullScreenAddTaskPageState();
}

class _FullScreenAddTaskPageState extends State<_FullScreenAddTaskPage>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  late final AnimationController _pencil;
  bool _isListening = false;
  String _dictationBaseText = '';

  @override
  void initState() {
    super.initState();
    _pencil = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _speech.stop();
    _pencil.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }
    final lang = context.read<AppState>().languageCode;
    final available = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(voiceInputErrorSnackText(error.errorMsg, lang)),
          ),
        );
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice input is unavailable in this browser/device. Try Chrome on Android or use keyboard input.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _isListening = true;
      _dictationBaseText = _controller.text.trim();
    });
    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.trim();
        final next = words.isEmpty
            ? _dictationBaseText
            : (_dictationBaseText.isEmpty ? words : '$_dictationBaseText $words');
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        if (result.finalResult && mounted) {
          setState(() => _isListening = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    final bp = context.bp;
    final padding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final top = padding.top;
    double bottom = padding.bottom + viewInsets.bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    if (kIsWeb && viewInsets.bottom == 0 && screenHeight < 780) {
      bottom += 220;
    }

    final ink = bp.textPrimary;
    final pencilStyle = GoogleFonts.caveat(
      fontSize: 28,
      height: 1.35,
      color: ink.withValues(alpha: 0.92),
      fontWeight: FontWeight.w600,
    );
    final wood = bp.talkAccent;
    final lead = bp.textSecondary;
    final eraser = Color.lerp(bp.toolAccentPomodoro, bp.secondary, 0.35)!;

    return Scaffold(
      backgroundColor: bp.scaffold,
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bp.backgroundGradient,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(8, top > 0 ? 4 : 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: bp.textSecondary),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _pencil,
                  builder: (context, child) {
                    final t = CurvedAnimation(
                      parent: _pencil,
                      curve: Curves.easeInOut,
                    ).value;
                    final wobble = math.sin(t * math.pi) * 0.12;
                    final nudge = (t - 0.5) * 6;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: Offset(nudge, 2 * math.sin(t * math.pi * 2)),
                          child: Transform.rotate(
                            angle: -0.35 + wobble,
                            child: CustomPaint(
                              size: const Size(56, 56),
                              painter: _PencilPainter(
                                wood: wood,
                                lead: lead,
                                eraser: eraser,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: child!,
                        ),
                      ],
                    );
                  },
                  child: Text(
                    tr('stickyNoteFullHint', lang: lang),
                    style: GoogleFonts.caveat(
                      fontSize: 32,
                      height: 1.2,
                      color: bp.textSecondary.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 16),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: bp.taskCardBg,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: bp.modalBorder),
                            boxShadow: [
                              BoxShadow(
                                color: bp.navShadow,
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                autocorrect: true,
                                enableSuggestions: true,
                                smartDashesType: SmartDashesType.enabled,
                                smartQuotesType: SmartQuotesType.enabled,
                                maxLines: null,
                                minLines: 8,
                                textAlignVertical: TextAlignVertical.top,
                                style: pencilStyle,
                                cursorColor: bp.primary.withValues(alpha: 0.85),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  alignLabelWithHint: true,
                                ),
                                textCapitalization: TextCapitalization.sentences,
                                onSubmitted: (_) => _submit(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleMic,
                              borderRadius: BorderRadius.circular(18),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: _isListening
                                      ? bp.toolAccentPomodoro.withValues(alpha: 0.92)
                                      : bp.primary.withValues(alpha: 0.92),
                                  border: Border.all(
                                    color: _isListening
                                        ? bp.micSelectedRing
                                        : bp.secondary.withValues(alpha: 0.85),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: bp.navShadow,
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                                  color: bp.onPrimary,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _scanFromPaper,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: bp.secondary.withValues(alpha: 0.92),
                                  border: Border.all(
                                    color: bp.primary.withValues(alpha: 0.85),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: bp.navShadow,
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.document_scanner_outlined,
                                  color: bp.onPrimary,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () => _submit(),
                            style: FilledButton.styleFrom(
                              backgroundColor: bp.primary,
                              foregroundColor: bp.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              iconSize: 24,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: Icon(Icons.check_rounded, color: bp.onPrimary),
                            label: Text(tr('addButton', lang: lang)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final added = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmTaskSheet(initialTitle: text),
    );
    if (!mounted) return;
    if (added == true) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _scanFromPaper() async {
    final text = await scanTextFromPaper(context);
    if (!mounted || text == null || text.trim().isEmpty) return;
    final merged = _controller.text.trim().isEmpty
        ? text.trim()
        : '${_controller.text.trim()} ${text.trim()}';
    _controller.value = TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(offset: merged.length),
    );
  }
}

/// Простая иконка карандаша (кисть).
class _PencilPainter extends CustomPainter {
  _PencilPainter({
    required this.wood,
    required this.lead,
    required this.eraser,
  });

  final Color wood;
  final Color lead;
  final Color eraser;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(math.pi / 6);

    final body = Path()
      ..moveTo(-6, -22)
      ..lineTo(6, -22)
      ..lineTo(5, 18)
      ..lineTo(0, 26)
      ..lineTo(-5, 18)
      ..close();
    canvas.drawPath(
      body,
      Paint()..color = wood,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-4, 18)
        ..lineTo(0, 26)
        ..lineTo(4, 18)
        ..close(),
      Paint()..color = lead,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6, -28, 12, 8),
        const Radius.circular(2),
      ),
      Paint()..color = eraser,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
