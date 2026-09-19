import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AtmosphereStyle { auth, app, trade }

class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({
    super.key,
    required this.child,
    this.style = AtmosphereStyle.app,
  });

  final Widget child;
  final AtmosphereStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: style == AtmosphereStyle.trade
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.canvas, colors.chart.withValues(alpha: 0.85)],
                  )
                : colors.pageGradient,
          ),
        ),
        if (style != AtmosphereStyle.trade)
          CustomPaint(painter: _GlowPainter(colors, style)),
        child,
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.colors, this.style);

  final TradePulseColors colors;
  final AtmosphereStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final cyan = Paint()..color = colors.glow;
    final violet = Paint()..color = colors.glowSecondary;
    final accent = Paint()..color = colors.accent.withValues(alpha: 0.08);

    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.08), 160, cyan);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.18), 180, violet);
    if (style == AtmosphereStyle.auth) {
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.82), 220, accent);
      canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.72), 120, violet);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.style != style;
  }
}
