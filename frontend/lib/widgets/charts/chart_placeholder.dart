import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ChartPlaceholder extends StatelessWidget {
  const ChartPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: colors.chart,
        child: CustomPaint(
          painter: _ChartGridPainter(colors.chartGrid),
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq_rounded, color: colors.accent, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    'Market chart will be connected in Phase 2',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartGridPainter extends CustomPainter {
  _ChartGridPainter(this.gridColor);

  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartGridPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor;
  }
}
