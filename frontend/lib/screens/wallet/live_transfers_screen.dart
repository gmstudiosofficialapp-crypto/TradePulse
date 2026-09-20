import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/live_wallet_models.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';

class LiveTransfersScreen extends StatelessWidget {
  const LiveTransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = AppScope.wallet(context);
    final colors = context.tpColors;
    final items = wallet.transfers;

    return AtmosphereBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Deposit & Withdraw History')),
      body: ResponsiveBody(
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  title: 'No transfers yet',
                  message: 'Simulated live deposits will appear here.',
                  icon: Icons.receipt_long_outlined,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final status = wallet.statusOf(item);
                  final failed = status == LiveTransferStatus.failed;
                  final kind = item.type == LiveTransferType.deposit ? 'Deposit' : 'Withdraw';
                  return PremiumCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AssetIcon(symbol: item.asset.iconSymbol, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$kind — ${item.asset.shortName}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(AppUtils.formatMoney(item.amount)),
                              if (item.txid.isNotEmpty)
                                Text(
                                  'TXID: ${AppUtils.maskTxid(item.txid)}',
                                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                                ),
                              Text(
                                AppUtils.formatTxnWhen(item.submittedAt),
                                style: TextStyle(fontSize: 12, color: colors.mutedText),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          failed ? '🔴 Failed' : '🟡 Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: failed ? colors.danger : colors.warning,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ),
    );
  }
}
