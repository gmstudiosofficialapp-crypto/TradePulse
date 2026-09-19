import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/otc_assets.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/breakpoints.dart';
import '../../widgets/brand/trade_pulse_logo.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../widgets/cards/asset_grid.dart';
import '../../widgets/cards/demo_balance_card.dart';
import '../../widgets/feedback/empty_state.dart';
import '../../widgets/layout/entrance.dart';
import '../../widgets/layout/responsive_body.dart';
import '../../widgets/layout/section_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(AppConstants.appName),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Entrance(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TradePulseLogo(compact: true, showTagline: true),
              ),
            ),
            const SizedBox(height: 20),
            const Entrance(
              delay: Duration(milliseconds: 60),
              child: DemoBalanceCard(),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Quick actions',
              subtitle: 'Open the simulated OTC workspace',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final buttonWidth =
                    compact ? constraints.maxWidth : 180.0;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: buttonWidth,
                      child: SecondaryButton(
                        label: 'Trade',
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            AppRoutes.trade,
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: buttonWidth,
                      child: SecondaryButton(
                        label: 'Markets',
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            AppRoutes.markets,
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: buttonWidth,
                      child: SecondaryButton(
                        label: 'History',
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            AppRoutes.history,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Market overview',
              subtitle: 'Simulated OTC overview until you open Markets or Trade',
            ),
            const SizedBox(height: 12),
            const AssetGrid(assets: OtcAssets.popular),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Recent activity'),
            const SizedBox(height: 12),
            const EmptyState(
              title: 'No demo trades yet',
              message: 'Activity appears after you place a demo trade.',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
