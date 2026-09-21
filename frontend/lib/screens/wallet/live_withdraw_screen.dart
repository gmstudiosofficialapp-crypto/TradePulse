import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class LiveWithdrawScreen extends StatelessWidget {
  const LiveWithdrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Withdraw'),
          actions: [
            IconButton(
              tooltip: 'Deposit & Withdraw History',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.liveTransfers),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
          ],
        ),
        body: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Live Balance',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppUtils.formatMoney(0),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PremiumCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: colors.danger,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Insufficient Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have sufficient Live Balance to make a withdrawal.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdrawal Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 14),
                    const _InfoRow(label: 'Minimum Withdrawal', value: r'$50.00'),
                    const _InfoRow(
                      label: 'Available Balance',
                      value: r'$0.00',
                    ),
                    const _InfoRow(
                      label: 'Withdrawal Status',
                      value: 'Unavailable',
                    ),
                    const _InfoRow(
                      label: 'Processing',
                      value: 'Not available',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const PrimaryButton(
                label: 'Withdraw',
                onPressed: null,
              ),
              const SizedBox(height: 12),
              Text(
                'Live withdrawals are currently unavailable. Your Live Balance is \$0.00.',
                style: TextStyle(color: colors.mutedText, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.mutedText, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
