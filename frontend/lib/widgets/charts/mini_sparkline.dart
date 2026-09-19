import 'package:flutter/material.dart';

class MiniSparkline extends StatelessWidget {
  const MiniSparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 52,
    this.height = 18,
  });

  final List<double> values;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(values: values, color: color),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      final y = size.height / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      return;
    }
    var minV = values.first;
    var maxV = values.first;
    for (final value in values) {
      if (value < minV) minV = value;
      if (value > maxV) maxV = value;
    }
    final span = (maxV - minV).abs() < 0.0000001 ? 1.0 : maxV - minV;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
