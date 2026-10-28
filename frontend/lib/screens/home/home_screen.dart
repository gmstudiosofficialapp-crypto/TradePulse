import 'package:flutter/material.dart';

import '../../core/constants/otc_assets.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/otc_asset.dart';
import '../../widgets/brand/asset_icon.dart';
import '../../widgets/brand/trade_pulse_logo.dart';
import '../../widgets/cards/asset_list_tile.dart';
import '../../widgets/cards/demo_balance_card.dart';
import '../../widgets/cards/live_cash_action_bar.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/feedback/signup_bonus_dialog.dart';
import '../../widgets/layout/entrance.dart';
import '../../widgets/layout/responsive_body.dart';
import '../../widgets/layout/section_header.dart';
import '../../widgets/pwa/pwa_install_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AppScope.auth(context).takeSignupBonusNotice()) return;
      SignupBonusDialog.show(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final live = AppScope.settings(context).isLiveMode;
    final settings = AppScope.settings(context);
    final trading = TradingScope.maybeOf(context);
    final recent = (trading?.liveHistory ?? [])
        .where((trade) => trade.result != null)
        .take(3)
        .toList();
    final overview = [
      ...OtcAssets.all.where((asset) => settings.isFavorite(asset.symbol)),
      ...OtcAssets.popular.where((asset) => !settings.isFavorite(asset.symbol)),
    ];
    final seen = <String>{};
    final uniqueOverview = <OtcAsset>[];
    for (final asset in overview) {
      if (seen.add(asset.symbol)) uniqueOverview.add(asset);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(strings.navHome),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Entrance(child: _HomeHero()),
            const SizedBox(height: 20),
            const Entrance(child: DemoBalanceCard()),
            const SizedBox(height: 12),
            const Entrance(
              delay: Duration(milliseconds: 40),
              child: LiveBalanceCard(),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: strings.manageFunds,
              subtitle: strings.manageFundsSubtitle,
            ),
            const SizedBox(height: 12),
            const Entrance(
              delay: Duration(milliseconds: 70),
              child: LiveCashActionBar(),
            ),
            const SizedBox(height: 12),
            Entrance(
              delay: const Duration(milliseconds: 90),
              child: PremiumCard(
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.leaderboard),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, color: context.tpColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.leaderboard,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.tpColors.mutedText),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: strings.recentActivity),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              EmptyState(
                title: strings.noTradesYet,
                message: live
                    ? 'Completed trades will appear here.'
                    : 'Activity appears after you place a trade.',
                icon: Icons.receipt_long_outlined,
              )
            else
              Column(
                children: [
                  for (final trade in recent) ...[
                    PremiumCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      onTap: () => Navigator.of(context)
                          .pushReplacementNamed(AppRoutes.history),
                      child: Row(
                        children: [
                          AssetIcon(symbol: trade.asset, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              trade.asset,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            trade.result ?? trade.status,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: switch (trade.result) {
                                'WIN' => context.tpColors.success,
                                'LOSS' => context.tpColors.danger,
                                _ => context.tpColors.mutedText,
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppUtils.formatSignedMoney(trade.profitLoss),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            const SizedBox(height: 16),
            SectionHeader(title: strings.marketOverview),
            const SizedBox(height: 12),
            for (final asset in uniqueOverview) ...[
              AssetListTile(asset: asset),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            const PwaInstallBanner(),
          ],
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    final strings = AppStrings.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TradePulseLogo(compact: true, showTagline: false),
          const SizedBox(height: 10),
          Text(
            strings.otcPlatform,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.tagline,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.mutedText,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}
