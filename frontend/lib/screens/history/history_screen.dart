import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/layout/entrance.dart';
import '../../widgets/layout/responsive_body.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final trading = TradingScope.maybeOf(context);
    final stats = trading?.statistics;
    final trades = (trading?.history ?? [])
        .where((trade) => trade.result != null)
        .where((trade) => _filter == 'ALL' || trade.result == _filter)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Trade History'),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Trade history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Closed positions on this account',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.mutedText,
                    ),
              ),
              const SizedBox(height: 16),
              if (stats != null)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatCard('Total Trades', '${stats.totalTrades}'),
                    _StatCard('Wins', '${stats.wins}'),
                    _StatCard('Losses', '${stats.losses}'),
                    _StatCard('Draws', '${stats.draws}'),
                    _StatCard('Win Rate', '${stats.winRate.toStringAsFixed(1)}%'),
                    _StatCard('Total P/L', AppUtils.formatSignedMoney(stats.totalProfitLoss)),
                    _StatCard('Balance', AppUtils.formatMoney(stats.currentBalance)),
                    _StatCard('Best Streak', '${stats.bestStreak}'),
                  ],
                ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in const ['ALL', 'WIN', 'LOSS', 'DRAW'])
                    ChoiceChip(
                      label: Text(item),
                      selected: _filter == item,
                      onSelected: (_) => setState(() => _filter = item),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (trades.isEmpty)
                const EmptyState(
                  title: 'No trades yet',
                  message: 'Your completed trades will appear here.',
                  icon: Icons.history,
                )
              else
                for (final entry in trades.asMap().entries)
                  Entrance(
                    delay: Duration(milliseconds: 40 * entry.key.clamp(0, 8)),
                    child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PremiumCard(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AssetIcon(symbol: entry.value.asset, size: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.value.asset,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                entry.value.direction,
                                style: TextStyle(
                                  color: entry.value.direction == 'BUY'
                                      ? colors.success
                                      : colors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                entry.value.result ?? entry.value.status,
                                style: TextStyle(
                                  color: _resultColor(colors, entry.value.result),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              _Meta(
                                'Entry',
                                '${AppUtils.formatPrice(entry.value.entryPrice)} → ${entry.value.expiryPrice == null ? 'pending' : AppUtils.formatPrice(entry.value.expiryPrice!)}',
                              ),
                              _Meta('Stake', AppUtils.formatMoney(entry.value.stake)),
                              _Meta(
                                'Duration',
                                AppUtils.formatExpiryLabel(entry.value.durationSeconds),
                              ),
                              _Meta(
                                'P/L',
                                AppUtils.formatSignedMoney(entry.value.profitLoss),
                              ),
                              _Meta('Opened', AppUtils.formatStamp(entry.value.entryTime)),
                              _Meta('Expiry', AppUtils.formatStamp(entry.value.expiryTime)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Color _resultColor(TradePulseColors colors, String? result) {
    return switch (result) {
      'WIN' => colors.success,
      'LOSS' => colors.danger,
      _ => colors.mutedText,
    };
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.mutedText)),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
