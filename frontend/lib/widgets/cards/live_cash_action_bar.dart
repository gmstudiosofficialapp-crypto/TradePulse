import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../buttons/pressable.dart';

class LiveCashActionBar extends StatelessWidget {
  const LiveCashActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 420;
        final deposit = _CashButton(
          label: 'Deposit',
          icon: Icons.south_west_rounded,
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.liveDeposit),
        );
        final withdraw = _CashButton(
          label: 'Withdraw',
          icon: Icons.north_east_rounded,
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.liveWithdraw),
        );
        if (stacked) {
          return Column(
            children: [
              deposit,
              const SizedBox(height: 10),
              withdraw,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: deposit),
            const SizedBox(width: 12),
            Expanded(child: withdraw),
          ],
        );
      },
    );
  }
}

class _CashButton extends StatelessWidget {
  const _CashButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Pressable(
      onPressed: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: colors.glow.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
