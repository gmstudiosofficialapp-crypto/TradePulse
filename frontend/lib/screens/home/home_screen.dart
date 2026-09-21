import 'package:flutter/material.dart';

import '../../core/constants/otc_assets.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/brand/trade_pulse_logo.dart';
import '../../widgets/cards/demo_balance_card.dart';
import '../../widgets/cards/asset_grid.dart';
import '../../widgets/cards/live_cash_action_bar.dart';
import '../../widgets/cards/quick_action_card.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/layout/entrance.dart';
import '../../widgets/layout/responsive_body.dart';
import '../../widgets/layout/section_header.dart';
import '../../widgets/pwa/pwa_install_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final live = AppScope.settings(context).isLiveMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Entrance(child: _HomeHero()),
            const SizedBox(height: 20),
            const Entrance(
              delay: Duration(milliseconds: 40),
              child: DemoBalanceCard(),
            ),
            const SizedBox(height: 12),
            const Entrance(
              delay: Duration(milliseconds: 70),
              child: LiveBalanceCard(),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Manage Funds',
              subtitle: 'Deposit or withdraw from your Live account',
            ),
            const SizedBox(height: 12),
            const Entrance(
              delay: Duration(milliseconds: 90),
              child: LiveCashActionBar(),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Quick actions',
              subtitle: 'Jump into the workspace',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = 12.0;
                final width = (constraints.maxWidth - gap * 2) / 3;
                final cardWidth = width < 96 ? constraints.maxWidth : width;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      height: 118,
                      child: Entrance(
                        delay: const Duration(milliseconds: 80),
                        child: QuickActionCard(
                          title: 'TRADE',
                          icon: Icons.candlestick_chart_outlined,
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                              AppRoutes.trade,
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: 118,
                      child: Entrance(
                        delay: const Duration(milliseconds: 120),
                        child: QuickActionCard(
                          title: 'MARKETS',
                          icon: Icons.grid_view_rounded,
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                              AppRoutes.markets,
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: 118,
                      child: Entrance(
                        delay: const Duration(milliseconds: 160),
                        child: QuickActionCard(
                          title: 'HISTORY',
                          icon: Icons.history,
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                              AppRoutes.history,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Market overview',
              subtitle: 'Open Markets or Trade for the full board',
            ),
            const SizedBox(height: 12),
            const Entrance(
              delay: Duration(milliseconds: 180),
              child: AssetGrid(assets: OtcAssets.popular),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Recent activity'),
            const SizedBox(height: 12),
            EmptyState(
              title: 'No trades yet',
              message: live
                  ? 'Completed trades will appear here.'
                  : 'Activity appears after you place a trade.',
              icon: Icons.receipt_long_outlined,
            ),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TradePulseLogo(compact: true, showTagline: false),
          const SizedBox(height: 10),
          Text(
            'OTC Trading Platform',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fast • Simple • Trading',
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
