import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../buttons/pressable.dart';

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Pressable(
      onPressed: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 108),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: colors.glow.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.accent, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
