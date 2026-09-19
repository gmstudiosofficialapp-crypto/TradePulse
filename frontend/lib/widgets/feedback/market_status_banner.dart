import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../models/market_models.dart';

class MarketStatusBanner extends StatelessWidget {
  const MarketStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final market = MarketScope.maybeOf(context);
    if (market == null) return const SizedBox.shrink();
    final colors = context.tpColors;
    final live = market.status.state == EngineState.liveSimulation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.sidebar.withValues(alpha: 0.92),
      child: Text(
        live
            ? '${AppConstants.liveSimulation}  ·  ${AppConstants.simulatedOtc}  ·  not live-money trading'
            : '${AppConstants.marketEngineOffline}  ·  ${AppConstants.simulatedOtc}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: live ? colors.accent : colors.mutedText,
            ),
      ),
    );
  }
}
