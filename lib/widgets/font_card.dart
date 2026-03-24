import 'package:flutter/material.dart';

class FontCard extends StatelessWidget {
  const FontCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: selected ? 1.0 : 0.985,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? const Color(0xFF78A6FF) : const Color(0xFFDCE1E8),
              width: selected ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle.copyWith(color: const Color(0xFF161719))),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: subtitleStyle.copyWith(color: const Color(0xFF454A53)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
