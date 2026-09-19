import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.emphasized = false,
    this.glass = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool emphasized;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card.withValues(
          alpha: glass ? 0.62 : (emphasized ? 0.95 : 0.88),
        ),
        borderRadius: BorderRadius.circular(glass ? 14 : 18),
        border: Border.all(color: colors.cardBorder.withValues(alpha: glass ? 0.55 : 1)),
        gradient: emphasized
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.card,
                  colors.canvasAlt.withValues(alpha: 0.9),
                ],
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: emphasized ? colors.glow : colors.glow.withValues(alpha: 0.35),
            blurRadius: emphasized ? 28 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          hoverColor: colors.accent.withValues(alpha: 0.08),
          splashColor: colors.accent.withValues(alpha: 0.16),
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}
