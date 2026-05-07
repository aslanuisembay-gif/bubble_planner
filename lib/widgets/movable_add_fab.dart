import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Плавающая кнопка «+»: перетаскивание по области стека, позиция сохраняется.
class MovableAddFab extends StatefulWidget {
  const MovableAddFab({
    super.key,
    required this.storageKey,
    required this.onPressed,
    required this.accent,
    required this.onPrimary,
    /// Минимальный отступ кнопки от низа родителя (безопасная зона / отступ от края).
    this.minBottom = 8,
    /// Дополнительно уменьшает вертикальный ход сверху (пиксели снизу «зарезервированы» под другой UI).
    this.bottomReserved = 0,
  });

  /// Уникальный ключ: `tasks_list`, `category_tasks`, и т.д.
  final String storageKey;
  final VoidCallback onPressed;
  final Color accent;
  final Color onPrimary;
  final double minBottom;
  final double bottomReserved;

  @override
  State<MovableAddFab> createState() => _MovableAddFabState();
}

class _MovableAddFabState extends State<MovableAddFab> {
  static const double _fab = 58;
  static const double _pad = 8;

  /// 0 = слева, 1 = справа
  double? _relX;
  /// 0 = низ (minBottom), 1 = верх допустимой области
  double? _relY;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final x = p.getDouble('movable_add_fab_${widget.storageKey}_rx');
      final y = p.getDouble('movable_add_fab_${widget.storageKey}_ry');
      if (!mounted) return;
      setState(() {
        _relX = x;
        _relY = y;
      });
    } catch (_) {}
  }

  Future<void> _save(double rx, double ry) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('movable_add_fab_${widget.storageKey}_rx', rx);
      await p.setDouble('movable_add_fab_${widget.storageKey}_ry', ry);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final minB = widget.minBottom;
        final res = widget.bottomReserved;

        final trackW = (maxW - _fab - 2 * _pad).clamp(0.0, double.infinity);
        // Вертикальный ход: от minB до верха минус отступ и резерв
        final trackB = (maxH - _fab - minB - _pad - res).clamp(0.0, double.infinity);

        final rx = (_relX ?? 1.0).clamp(0.0, 1.0);
        final ry = (_relY ?? 0.0).clamp(0.0, 1.0);

        final left = _pad + rx * trackW;
        final bottom = minB + ry * trackB;

        return Stack(
          children: [
            Positioned(
              left: left,
              bottom: bottom,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  if (trackW <= 0 && trackB <= 0) return;
                  setState(() {
                    final curRx = _relX ?? 1.0;
                    final curRy = _relY ?? 0.0;
                    final curLeft = _pad + curRx * trackW;
                    final curBottom = minB + curRy * trackB;
                    if (trackW > 0) {
                      _relX = ((curLeft + details.delta.dx - _pad) / trackW).clamp(0.0, 1.0);
                    }
                    if (trackB > 0) {
                      _relY = ((curBottom - details.delta.dy - minB) / trackB).clamp(0.0, 1.0);
                    }
                  });
                },
                onPanEnd: (_) {
                  if (_relX != null && _relY != null) {
                    _save(_relX!, _relY!);
                  }
                },
                child: Material(
                  color: widget.accent.withValues(alpha: 0.78),
                  shape: const CircleBorder(),
                  elevation: 16,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onPressed,
                    child: SizedBox(
                      width: _fab,
                      height: _fab,
                      child: Icon(Icons.add, color: widget.onPrimary, size: 26),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
