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
    final balance = trading?.demoDisplayBalance ?? 10000;

    return PremiumCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Demo Balance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Chip(
                label: const Text('DEMO'),
                visualDensity: VisualDensity.compact,
                color: WidgetStatePropertyAll(
                  colors.accent.withValues(alpha: 0.16),
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
        ],
      ),
    );
  }
}

class LiveBalanceCard extends StatelessWidget {
  const LiveBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return PremiumCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Live Balance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Chip(
                label: const Text('LIVE'),
                visualDensity: VisualDensity.compact,
                color: WidgetStatePropertyAll(
                  colors.danger.withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppUtils.formatMoney(0),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Live trading is unavailable. No live balance.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.mutedText,
                ),
          ),
        ],
      ),
    );
  }
}
