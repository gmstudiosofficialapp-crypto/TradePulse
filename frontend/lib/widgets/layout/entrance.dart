import 'package:flutter/material.dart';

class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  static final _tween = Tween<double>(begin: 0, end: 1);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: _tween,
      duration: const Duration(milliseconds: 420) + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final t = ((value * 1000) - delay.inMilliseconds) / 420;
        final clamped = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - clamped)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
