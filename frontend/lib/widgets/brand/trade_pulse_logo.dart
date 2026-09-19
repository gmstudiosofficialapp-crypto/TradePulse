import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

class TradePulseLogo extends StatelessWidget {
  const TradePulseLogo({
    super.key,
    this.compact = false,
    this.showTagline = true,
  });

  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final size = compact ? 36.0 : 64.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [colors.accent, colors.accentSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.glow,
                blurRadius: 22,
              ),
            ],
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: compact ? 20 : 32,
          ),
        ),
        SizedBox(height: compact ? 8 : 14),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            AppConstants.tagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                ),
          ),
        ],
      ],
    );
  }
}
