import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import 'premium_card.dart';

class DemoBalanceCard extends StatelessWidget {
  const DemoBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final trading = TradingScope.maybeOf(context);
    final live = AppScope.settings(context).isLiveMode;
    final balance = live ? 0.0 : (trading?.demoDisplayBalance ?? 10000);

    return PremiumCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Balance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Chip(
                label: Text(live ? 'LIVE' : 'DEMO'),
                visualDensity: VisualDensity.compact,
                color: WidgetStatePropertyAll(
                  (live ? colors.danger : colors.accent).withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppUtils.formatMoney(balance),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (live) ...[
            const SizedBox(height: 8),
            Text(
              'Live trading is unavailable. No live balance.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.mutedText,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
