import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';

BorderRadius _organicRadius(String id, double w, double h) {
  final seed = id.hashCode.abs();
  double corner(int i) {
    final base = (w + h) * 0.22;
    final jitter = 0.88 + ((seed >> (i * 4)) & 0x1f) / 128.0;
    return (base * jitter).clamp(18.0, base * 1.15);
  }

  return BorderRadius.only(
    topLeft: Radius.circular(corner(0)),
    topRight: Radius.circular(corner(1)),
    bottomRight: Radius.circular(corner(2)),
    bottomLeft: Radius.circular(corner(3)),
  );
}

class BubbleWidget extends StatefulWidget {
  const BubbleWidget({
    super.key,
    required this.category,
    required this.onTap,
    required this.parallaxOffset,
  });

  final BubbleCategory category;
  final VoidCallback onTap;
  final Offset parallaxOffset;

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _driftY;
  late final Animation<double> _driftX;
  late final Animation<double> _tilt;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: bubbleFloatDurationMs(widget.category.id).round()),
    )..repeat(reverse: true);

    _driftY = Tween<double>(begin: -9, end: 11).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutCubic),
    );
    _driftX = Tween<double>(begin: -6, end: 7).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: const Interval(0.12, 0.92, curve: Curves.easeInOut),
      ),
    );
    _tilt = Tween<double>(begin: -0.026, end: 0.026).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final s = category.size;
    final w = s * 1.08;
    final h = s * 0.92;
    final shape = _organicRadius(category.id, w, h);

    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Positioned(
          left: category.position.dx + _driftX.value + widget.parallaxOffset.dx,
          top: category.position.dy + _driftY.value + widget.parallaxOffset.dy,
          child: child!,
        );
      },
      child: Transform.rotate(
        angle: _tilt.value,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: Hero(
            tag: 'bubble-${category.id}',
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              scale: _pressed ? 0.96 : 1.0,
              child: SizedBox(
                width: s,
                height: s,
                child: Center(
                  child: Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: shape,
                      gradient: RadialGradient(
                        center: const Alignment(-0.28, -0.42),
                        radius: 1.05,
                        colors: [
                          category.color.withValues(alpha: 0.97),
                          category.color.withValues(alpha: 0.52),
                          const Color(0xFF12131A).withValues(alpha: 0.88),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: category.color.withValues(alpha: 0.38),
                          blurRadius: 52,
                          spreadRadius: -4,
                          offset: const Offset(0, 18),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 0,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.12),
                          blurRadius: 18,
                          spreadRadius: -6,
                          offset: const Offset(-6, -10),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: ClipRRect(
                      borderRadius: shape,
                      child: Stack(
                        children: [
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: const SizedBox.expand(),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  category.title,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${category.tasksCount} tasks',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.84),
                                      ),
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
            ),
          ),
        ),
      ),
    );
  }
}
