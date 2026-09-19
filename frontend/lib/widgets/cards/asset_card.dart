import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/otc_assets.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/market_models.dart';
import '../../models/otc_asset.dart';
import '../brand/asset_icon.dart';
import '../charts/mini_sparkline.dart';
import 'premium_card.dart';

class AssetCard extends StatelessWidget {
  const AssetCard({super.key, required this.asset});

  final OtcAsset asset;

  Future<void> _openTrade(BuildContext context) async {
    final market = AppScope.market(context);
    await market.focusAsset(asset.symbol);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.trade,
      arguments: asset.symbol,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final market = MarketScope.maybeOf(context);
    final settings = SettingsScope.of(context);
    final quote = market?.quotes[asset.symbol];
    final live = market?.status.state == EngineState.liveSimulation;
    final changeColor = (quote?.changePct ?? 0) >= 0
        ? colors.success
        : colors.danger;
    final favorite = settings.isFavorite(asset.symbol);

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _openTrade(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AssetIcon(symbol: asset.symbol, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  asset.symbol,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: favorite ? 'Unpin' : 'Pin',
                onPressed: () => settings.toggleFavorite(asset.symbol),
                icon: Icon(
                  favorite ? Icons.star : Icons.star_border,
                  color: favorite ? colors.accent : colors.mutedText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OTC',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.accent,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            OtcAssets.categoryLabel(asset.category),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.mutedText,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  quote == null
                      ? AppConstants.priceUnavailable
                      : '\$${AppUtils.formatPrice(quote.price)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              MiniSparkline(
                values: market?.priceTrail[asset.symbol] ?? const [],
                color: changeColor,
                width: 64,
                height: 22,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quote == null
                ? AppConstants.simulatedOtc
                : '${AppUtils.formatChange(quote.changePct)}  ·  ${AppConstants.simulatedOtc}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: quote == null ? colors.mutedText : changeColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            live ? 'LIVE SIMULATION' : AppConstants.marketEngineOffline,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: live ? colors.accent : colors.mutedText,
                ),
          ),
        ],
      ),
    );
  }
}
