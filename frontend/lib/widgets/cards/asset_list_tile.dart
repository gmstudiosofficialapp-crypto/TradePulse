import 'package:flutter/material.dart';

import '../../core/constants/otc_assets.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/otc_asset.dart';
import '../brand/asset_icon.dart';
import '../charts/mini_sparkline.dart';
import 'premium_card.dart';

class AssetListTile extends StatelessWidget {
  const AssetListTile({super.key, required this.asset});

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
    final change = quote?.changePct ?? 0;
    final changeColor = change >= 0 ? colors.success : colors.danger;
    final favorite = settings.isFavorite(asset.symbol);

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      onTap: () => _openTrade(context),
      child: Row(
        children: [
          AssetIcon(symbol: asset.symbol, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  OtcAssets.payoutLabel(asset.symbol),
                  style: TextStyle(color: colors.mutedText, fontSize: 11),
                ),
              ],
            ),
          ),
          MiniSparkline(
            values: market?.priceTrail[asset.symbol] ?? const [],
            color: changeColor,
            width: 52,
            height: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quote == null
                    ? '—'
                    : OtcAssets.formatAssetPrice(asset.symbol, quote.price),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              Text(
                quote == null ? '' : AppUtils.formatChange(change),
                style: TextStyle(color: changeColor, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => settings.toggleFavorite(asset.symbol),
            icon: Icon(
              favorite ? Icons.star : Icons.star_border,
              color: favorite ? colors.accent : colors.mutedText,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
