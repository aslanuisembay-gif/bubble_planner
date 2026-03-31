import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../translations.dart';

/// Иконка помидора (как в топовых Pomodoro-приложениях): градиент, блик, чашелистик.
class PomodoroTomatoIcon extends StatelessWidget {
  const PomodoroTomatoIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TomatoIconPainter(),
    );
  }
}

class _TomatoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Чашелистик
    final stem = Path()
      ..moveTo(cx - w * 0.22, h * 0.22)
      ..quadraticBezierTo(cx, h * 0.02, cx + w * 0.22, h * 0.22)
      ..lineTo(cx + w * 0.12, h * 0.28)
      ..quadraticBezierTo(cx, h * 0.18, cx - w * 0.12, h * 0.28)
      ..close();
    canvas.drawPath(
      stem,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.35)),
    );

    // Тело
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, h * 0.58), width: w * 0.92, height: h * 0.72),
      Radius.circular(w * 0.42),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF6B5C), Color(0xFFE53935), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, h * 0.2, w, h)),
    );

    // Блик
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - w * 0.18, h * 0.48),
        width: w * 0.22,
        height: h * 0.14,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    // Складка снизу
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, h * 0.78), width: w * 0.5, height: h * 0.2),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      Paint()
        ..color = const Color(0xFFB71C1C).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _PomodoroPhase { focus, shortBreak }

/// Круговой таймер Pomodoro (25 / 5 мин), стиль премиальных приложений.
class PomodoroSheet extends StatefulWidget {
  const PomodoroSheet({super.key});

  @override
  State<PomodoroSheet> createState() => _PomodoroSheetState();
}

class _PomodoroSheetState extends State<PomodoroSheet> {
  static const int _defaultFocusSec = 25 * 60;
  static const int _defaultBreakSec = 5 * 60;
  static const String _kPrefsPomodoroFocusMin = 'bubble_planner_pomodoro_focus_min_v1';
  static const String _kPrefsPomodoroBreakMin = 'bubble_planner_pomodoro_break_min_v1';

  _PomodoroPhase _phase = _PomodoroPhase.focus;
  int _focusSec = _defaultFocusSec;
  int _breakSec = _defaultBreakSec;
  int _remaining = _defaultFocusSec;
  bool _running = false;
  Timer? _timer;

  Color get _accent =>
      _phase == _PomodoroPhase.focus ? const Color(0xFFE53935) : const Color(0xFF43A047);

  int get _totalSec => _phase == _PomodoroPhase.focus ? _focusSec : _breakSec;

  double get _progress => _totalSec <= 0 ? 0 : _remaining / _totalSec;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final focusMin = p.getInt(_kPrefsPomodoroFocusMin);
      final breakMin = p.getInt(_kPrefsPomodoroBreakMin);
      final nextFocus = (focusMin == null ? null : focusMin.clamp(1, 240))?.toInt();
      final nextBreak = (breakMin == null ? null : breakMin.clamp(1, 240))?.toInt();
      if (!mounted) return;
      setState(() {
        if (nextFocus != null) _focusSec = nextFocus * 60;
        if (nextBreak != null) _breakSec = nextBreak * 60;
        _remaining = _totalSec;
      });
    } catch (_) {
      // ignore: best-effort prefs
    }
  }

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();
    final lang = context.read<AppState>().languageCode;
    final initialFocus = (_focusSec / 60).round().clamp(1, 240);
    final initialBreak = (_breakSec / 60).round().clamp(1, 240);

    int focusMin = initialFocus;
    int breakMin = initialBreak;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF151018),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: StatefulBuilder(
              builder: (ctx, setInner) {
                Widget row({
                  required String title,
                  required int value,
                  required VoidCallback onMinus,
                  required VoidCallback onPlus,
                }) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      _miniIconButton(Icons.remove_rounded, onMinus),
                      const SizedBox(width: 10),
                      Container(
                        width: 72,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Text(
                          '$value',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _miniIconButton(Icons.add_rounded, onPlus),
                      const SizedBox(width: 8),
                      Text(
                        tr('pomodoroMin', lang: lang),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                      ),
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          tr('pomodoroSettings', lang: lang),
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    row(
                      title: tr('pomodoroFocusMinutes', lang: lang),
                      value: focusMin,
                      onMinus: () => setInner(() => focusMin = (focusMin - 1).clamp(1, 240)),
                      onPlus: () => setInner(() => focusMin = (focusMin + 1).clamp(1, 240)),
                    ),
                    const SizedBox(height: 12),
                    row(
                      title: tr('pomodoroBreakMinutes', lang: lang),
                      value: breakMin,
                      onMinus: () => setInner(() => breakMin = (breakMin - 1).clamp(1, 240)),
                      onPlus: () => setInner(() => breakMin = (breakMin + 1).clamp(1, 240)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        try {
                          final p = await SharedPreferences.getInstance();
                          await p.setInt(_kPrefsPomodoroFocusMin, focusMin);
                          await p.setInt(_kPrefsPomodoroBreakMin, breakMin);
                        } catch (_) {}
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {
                          _focusSec = focusMin * 60;
                          _breakSec = breakMin * 60;
                          _remaining = _totalSec;
                          _running = false;
                        });
                        _timer?.cancel();
                      },
                      child: Text(tr('save', lang: lang)),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _miniIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer _) {
    if (!mounted) return;
    setState(() {
      if (_remaining <= 1) {
        _remaining = 0;
        _onPhaseComplete();
      } else {
        _remaining--;
      }
    });
  }

  void _onPhaseComplete() {
    _timer?.cancel();
    _running = false;
    HapticFeedback.heavyImpact();
    setState(() {
      if (_phase == _PomodoroPhase.focus) {
        _phase = _PomodoroPhase.shortBreak;
        _remaining = _breakSec;
      } else {
        _phase = _PomodoroPhase.focus;
        _remaining = _focusSec;
      }
    });
  }

  void _toggleRun() {
    HapticFeedback.lightImpact();
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      if (_remaining <= 0) {
        setState(() => _remaining = _totalSec);
      }
      setState(() => _running = true);
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = _totalSec;
    });
  }

  void _skip() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    setState(() {
      _running = false;
      if (_phase == _PomodoroPhase.focus) {
        _phase = _PomodoroPhase.shortBreak;
        _remaining = _breakSec;
      } else {
        _phase = _PomodoroPhase.focus;
        _remaining = _focusSec;
      }
    });
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    final phaseLabel =
        _phase == _PomodoroPhase.focus ? tr('pomodoroFocus', lang: lang) : tr('pomodoroBreak', lang: lang);
    final subtitle = trFill(
      'pomodoroSubtitle',
      {
        'f': '${(_focusSec / 60).round()}',
        'b': '${(_breakSec / 60).round()}',
      },
      lang: lang,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      tr('pomodoroTitle', lang: lang),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                tooltip: tr('pomodoroSettings', lang: lang),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(300, 300),
                        painter: _PomodoroRingPainter(
                          progress: _progress,
                          color: _accent,
                          trackColor: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PomodoroTomatoIcon(size: 40),
                          const SizedBox(height: 12),
                          Text(
                            phaseLabel.toUpperCase(),
                            style: TextStyle(
                              color: _accent.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fmt(_remaining),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w200,
                              fontSize: 56,
                              height: 1,
                              letterSpacing: 2,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundAction(
                      icon: Icons.refresh_rounded,
                      label: tr('pomodoroReset', lang: lang),
                      onTap: _reset,
                    ),
                    const SizedBox(width: 20),
                    Material(
                      color: _accent,
                      elevation: 12,
                      shadowColor: _accent.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _toggleRun,
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: Icon(
                            _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    _RoundAction(
                      icon: Icons.skip_next_rounded,
                      label: tr('pomodoroSkip', lang: lang),
                      onTap: _skip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child: Text(
            tr('pomodoroHint', lang: lang),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.08),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icon, color: Colors.white70, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PomodoroRingPainter extends CustomPainter {
  _PomodoroRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const stroke = 14.0;
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, radius, trackPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PomodoroRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Кнопка на главном экране: открывает лист Pomodoro.
class PomodoroHomeButton extends StatelessWidget {
  const PomodoroHomeButton({super.key, required this.languageCode});

  final String languageCode;

  static void open(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.viewPaddingOf(ctx).top + 6),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            height: MediaQuery.sizeOf(ctx).height * 0.92,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1C181A),
                  Color(0xFF0E0C0D),
                ],
              ),
            ),
            child: const PomodoroSheet(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = tr('pomodoroButton', lang: languageCode);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => open(context),
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF5F52), Color(0xFFD32F2F), Color(0xFFB71C1C)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PomodoroTomatoIcon(size: 26),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
