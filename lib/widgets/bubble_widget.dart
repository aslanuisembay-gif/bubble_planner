import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';

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

class _BubbleWidgetState extends State<BubbleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: bubbleFloatDurationMs(widget.category.id).round()),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
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
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Positioned(
          left: category.position.dx + widget.parallaxOffset.dx,
          top: category.position.dy + _floatAnimation.value + widget.parallaxOffset.dy,
          child: child!,
        );
      },
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
            duration: const Duration(milliseconds: 160),
            scale: _pressed ? 0.97 : 1.0,
            child: Container(
              width: category.size,
              height: category.size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.45),
                  radius: 1.0,
                  colors: [
                    category.color.withOpacity(0.98),
                    category.color.withOpacity(0.58),
                    const Color(0xFF12131A).withOpacity(0.92),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: category.color.withOpacity(0.52),
                    blurRadius: 44,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: const SizedBox.expand(),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            category.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${category.tasksCount} tasks',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.82),
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
    );
  }
}
